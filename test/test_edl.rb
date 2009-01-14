require File.dirname(__FILE__) + '/../lib/edl'
require File.dirname(__FILE__) + '/../lib/edl/cutter'
require File.dirname(__FILE__) + '/../lib/edl/grabber'

require 'rubygems'
require 'test/unit'
require 'flexmock'
require 'flexmock/test_unit'

TRAILER_EDL                 = File.dirname(__FILE__) + '/samples/TRAILER_EDL.edl'
SIMPLE_DISSOLVE             = File.dirname(__FILE__) + '/samples/SIMPLE_DISSOLVE.EDL'
SPLICEME                    = File.dirname(__FILE__) + '/samples/SPLICEME.EDL'
SIMPLE_TIMEWARP             = File.dirname(__FILE__) + '/samples/TIMEWARP.EDL'
SLOMO_TIMEWARP              = File.dirname(__FILE__) + '/samples/TIMEWARP_HALF.EDL'
FORTY_FIVER                 = File.dirname(__FILE__) + '/samples/45S_SAMPLE.EDL'
REVERSE                     = File.dirname(__FILE__) + '/samples/REVERSE.EDL'
SPEEDUP_AND_FADEOUT         = File.dirname(__FILE__) + '/samples/SPEEDUP_AND_FADEOUT.EDL'
SPEEDUP_REVERSE_AND_FADEOUT = File.dirname(__FILE__) + '/samples/SPEEDUP_REVERSE_AND_FADEOUT.EDL'

class TestEvent < Test::Unit::TestCase
  def test_attributes_defined
    evt = EDL::Event.new
    %w(  num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc ).each do | em |
      assert_respond_to evt, em
    end
  end
end

class Test::Unit::TestCase
  def parse_evt(matcher_klass, line)
    stack = []
    matcher_klass.new.apply(stack, line)
    stack.pop
  end
end

class TestParser < Test::Unit::TestCase
  
  def test_inst
    assert_nothing_raised { EDL::Parser.new }
  end
  
  def test_inits_matchers_with_framerate
    p = EDL::Parser.new(30)
    matchers = p.get_matchers
    event_matcher = matchers.find{|e| e.is_a?(EDL::EventMatcher) }
    assert_equal 30, event_matcher.fps
  end
  
  def test_timecode_from_elements
    elems = ["08", "04", "24", "24"]
    assert_nothing_raised { @tc = EDL::Parser.timecode_from_line_elements(elems, 30) }
    assert_kind_of Timecode, @tc
    assert_equal "08:04:24:24", @tc.to_s
    assert_equal 30, @tc.fps
    assert elems.empty?, "The elements used for timecode should have been removed from the array"
  end
  
  def test_parse_from_string
    p = EDL::Parser.new
    assert_nothing_raised{ @edl = p.parse File.read(SIMPLE_DISSOLVE) }
    assert_kind_of EDL::List, @edl
    assert_equal 2, @edl.length
  end
    
  def test_dissolve
    p = EDL::Parser.new
    assert_nothing_raised{ @edl = p.parse File.open(SIMPLE_DISSOLVE) }
    assert_kind_of EDL::List, @edl
    assert_equal 2, @edl.length
    
    first = @edl[0]
    assert_kind_of EDL::Event, first
    
    second = @edl[1]
    assert_kind_of EDL::Event, second
    assert second.has_transition?
    
    no_trans = @edl.without_transitions
    
    assert_equal 2, no_trans.length
    target_tc = (Timecode.parse('01:00:00:00') + 43)
    assert_equal target_tc, no_trans[0].rec_end_tc, 
      "The incoming clip should have been extended by the length of the dissolve"
    
    target_tc = Timecode.parse('01:00:00:00')
    assert_equal target_tc, no_trans[1].rec_start_tc
      "The outgoing clip should have been left in place"
  end
  
  def test_spliced
    p = EDL::Parser.new
    assert_nothing_raised{ @edl = p.parse(File.open(SPLICEME)) }
    assert_equal 2, @edl.length
    
    spliced = @edl.spliced
    assert_equal 1, spliced.length, "Should have been spliced to one event"
  end
end

class TimewarpMatcherTest < Test::Unit::TestCase

  def test_parses_as_one_event
    @edl = EDL::Parser.new.parse(File.open(SIMPLE_TIMEWARP))
    assert_kind_of EDL::List, @edl
    assert_equal 1, @edl.length
  end

  def test_timewarp_attributes
    @edl = EDL::Parser.new.parse(File.open(SIMPLE_TIMEWARP))
    assert_kind_of EDL::List, @edl
    assert_equal 1, @edl.length
    
    clip = @edl[0]
    assert clip.has_timewarp?, "Should respond true to has_timewarp?"
    assert_not_nil clip.timewarp
    assert_kind_of EDL::Timewarp, clip.timewarp

    assert clip.timewarp.actual_src_end_tc > clip.src_end_tc
    assert_equal "03:03:24:18", clip.timewarp.actual_src_end_tc.to_s
    assert_equal 124, clip.timewarp.actual_length_of_source
    assert !clip.timewarp.reverse?
    assert !clip.reverse?
    
  end
  
  def test_timwarp_slomo
    @edl = EDL::Parser.new.parse(File.open(SLOMO_TIMEWARP))
    clip = @edl[0]
    assert clip.has_timewarp?, "Should respond true to has_timewarp?"
    assert_not_nil clip.timewarp
    assert_kind_of EDL::Timewarp, clip.timewarp

    assert clip.timewarp.actual_src_end_tc < clip.src_end_tc
    assert_equal "03:03:19:24", clip.timewarp.actual_src_end_tc.to_s
    assert_equal 10, clip.rec_length
    assert_equal 5, clip.src_length
    assert_equal 5, clip.timewarp.actual_length_of_source
    assert_equal 50, clip.timewarp.speed_in_percent.to_i
    assert !clip.timewarp.reverse?
    
  end

end

class ReverseTimewarpTest < Test::Unit::TestCase
  def test_parse
    @edl = EDL::Parser.new.parse(File.open(REVERSE))
    assert_equal 1, @edl.length
    
    clip = @edl[0]
    assert_equal 52, clip.rec_length
    
    assert clip.has_timewarp?, "Should respond true to has_timewarp?"
    tw = clip.timewarp
    
    assert_equal( -25, tw.actual_framerate.to_i)
    assert tw.reverse?
    assert clip.reverse?
    assert clip.reversed?
    assert_equal 52, clip.src_length
    assert_equal clip.src_start_tc, tw.actual_src_end_tc
    assert_equal clip.src_start_tc - 52, tw.actual_src_start_tc
    assert_equal( -100, clip.timewarp.speed_in_percent.to_i)
    
  end
end

class EventMatcherTest < Test::Unit::TestCase

  EVT_PATTERNS = [
    '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17', 
    '021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05', 
    '022  008C     V     C        08:08:01:23 08:08:02:18 01:00:27:05 01:00:28:00', 
    '023  008C     V     C        08:07:30:02 08:07:30:21 01:00:28:00 01:00:28:19', 
    '024        AX V     C        00:00:00:00 00:00:01:00 01:00:28:19 01:00:29:19', 
    '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19', 
    '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20',
  ]

  def test_clip_generation_from_line
    m = EDL::EventMatcher.new(25)
    
    clip = m.apply([],
      '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17'
    )
    
    assert_not_nil clip
    assert_kind_of EDL::Event, clip
    assert_equal '020', clip.num
    assert_equal '008C', clip.reel
    assert_equal 'V', clip.track
    assert_equal '08:04:24:24', clip.src_start_tc.to_s
    assert_equal '08:04:25:19', clip.src_end_tc.to_s
    assert_equal '01:00:25:22', clip.rec_start_tc.to_s
    assert_equal '01:00:26:17', clip.rec_end_tc.to_s
    
    evt_len = Timecode.parse('01:00:26:17') - Timecode.parse('01:00:25:22')
    assert_equal evt_len, clip.rec_length
    assert_equal evt_len, clip.src_length
    
    assert_equal evt_len, clip.capture_length
    
  end
  
  def test_dissolve_generation_from_line
    m = EDL::EventMatcher.new(25)
    dissolve = m.apply([],
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
    assert_not_nil dissolve
    assert_kind_of EDL::Event, dissolve
    assert_equal '025', dissolve.num
    assert_equal 'GEN', dissolve.reel
    assert_equal 'V', dissolve.track
    
    assert dissolve.has_transition?
    assert_not_nil dissolve.transition
    assert_kind_of EDL::Dissolve, dissolve.transition
    assert_equal 25, dissolve.transition.duration
  end
  
  def test_dissolve_generation_sets_flag_on_previous_evt
    m = EDL::EventMatcher.new(25)
    previous_evt = flexmock
    previous_evt.should_receive(:ends_with_a_transition=).with(true).once
    previous_evt.should_receive(:outgoing_transition_duration=).with(25).once
    dissolve = m.apply([previous_evt],
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
  end

  def test_wipe_generation_from_line
    m = EDL::EventMatcher.new(25)
    wipe = m.apply([],
      '025  GEN      V     W001  025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
    assert_not_nil wipe
    assert_kind_of EDL::Event, wipe
    assert wipe.generator?
    assert_equal '025', wipe.num
    assert_equal 'GEN', wipe.reel
    assert_equal 'V', wipe.track
    
    assert wipe.has_transition?
    
    assert_not_nil wipe.transition
    assert_kind_of EDL::Wipe, wipe.transition
    assert_equal '025', wipe.transition.duration
    assert_equal '001', wipe.transition.smpte_wipe_index
  end
  
  def test_black_generation_from_line
    m = EDL::EventMatcher.new(25)
    black = m.apply([],
      '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19' 
    )
    
    assert_not_nil black
    
    assert black.black?, "Black should be black?"
    assert black.slug?, "Black should be slug?"
    
    assert black.generator?, "Should be generator?"
    assert_equal '025', black.num
    assert_equal 'BL', black.reel
    assert_equal 'V', black.track
  end
  
  def test_matches_all_patterns
    EVT_PATTERNS.each do | pat |
      assert EDL::EventMatcher.new(25).matches?(pat), "EventMatcher should match #{pat}"
    end
  end
  
  def test_framerate_passed_to_timecodes
    m = EDL::EventMatcher.new(30)
    clip = m.apply([],
      '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17'
    )
    assert_equal 30, clip.rec_start_tc.fps 
    assert_equal 30, clip.rec_end_tc.fps 

    assert_equal 30, clip.src_start_tc.fps 
    assert_equal 30, clip.src_end_tc.fps 
    
  end
end

class CommentMatcherTest  < Test::Unit::TestCase
  def test_matches
    line = "* COMMENT: PURE BULLSHIT"
    assert EDL::CommentMatcher.new.matches?(line)
  end

  def test_apply
    line = "* COMMENT: PURE BULLSHIT"

    comments = []
    mok_evt = flexmock

    2.times { mok_evt.should_receive(:comments).and_return(comments) }
    2.times { EDL::CommentMatcher.new.apply([mok_evt], line) }

    assert_equal ["COMMENT: PURE BULLSHIT", "COMMENT: PURE BULLSHIT"], mok_evt.comments 
  end
end

class ClipNameMatcherTest < Test::Unit::TestCase
  def test_matches
    line = "* FROM CLIP NAME:  TAPE_6-10.MOV"
    assert EDL::NameMatcher.new.matches?(line)
  end
  
  def test_apply
    line = "* FROM CLIP NAME:  TAPE_6-10.MOV"

    mok_evt = flexmock
    comments = []
    mok_evt.should_receive(:clip_name=).with('TAPE_6-10.MOV').once
    mok_evt.should_receive(:comments).and_return(comments).once
    
    EDL::NameMatcher.new.apply([mok_evt], line)
    assert_equal ["FROM CLIP NAME:  TAPE_6-10.MOV"], comments 
  end
end

class EffectMatcherTest < Test::Unit::TestCase
  def test_matches
    line = "* EFFECT NAME: CROSS DISSOLVE"
    assert EDL::EffectMatcher.new.matches?(line)
  end
  
  def test_apply
    line = "* EFFECT NAME: CROSS DISSOLVE"
    mok_evt, mok_transition = flexmock, flexmock
    cmt = []
    
    mok_evt.should_receive(:transition).once.and_return(mok_transition)
    mok_evt.should_receive(:comments).once.and_return(cmt)

    mok_transition.should_receive(:effect=).with("CROSS DISSOLVE").once
    
    EDL::EffectMatcher.new.apply([mok_evt], line)
    
    assert_equal ["EFFECT NAME: CROSS DISSOLVE"], cmt
  end
end

class ComplexTest < Test::Unit::TestCase
  def test_parses_cleanly
    assert_nothing_raised { EDL::Parser.new.parse(File.open(FORTY_FIVER)) }
  end
  
  def test_from_zero
    complex = EDL::Parser.new.parse(File.open(FORTY_FIVER))
    
    from_zero = complex.from_zero
    assert_equal '00:00:00:00', from_zero[0].rec_start_tc.to_s,
      "The starting timecode of the first event should have been shifted to zero"
    assert_equal '00:00:42:16', from_zero[-1].rec_end_tc.to_s,
      "The ending timecode of the last event should have been shifted 10 hours back"
  end
end

class SpeedupAndFadeTest < Test::Unit::TestCase
  def test_proper_timings
    list = EDL::Parser.new.parse(File.open(SPEEDUP_AND_FADEOUT))
    
    assert_equal 2, list.length
    first_evt = list[0]
    
    assert_equal "01:00:40:00", first_evt.capture_to_tc.to_s,
      "Will need to capture 40 seconds even though the event is smaller"
  end

  def test_proper_timings_with_reverse
    list = EDL::Parser.new.parse(File.open(SPEEDUP_REVERSE_AND_FADEOUT))
    
    assert_equal 2, list.length
    first_evt = list[0]
    
    assert_equal "01:00:00:00", first_evt.capture_from_tc.to_s
    assert_equal "01:00:40:00", first_evt.capture_to_tc.to_s,
      "Will need to capture 40 seconds even though the event is smaller"
  end
  
  
end