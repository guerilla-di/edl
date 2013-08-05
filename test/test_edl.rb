require "rubygems"
require "bundler"
Bundler.require(:default, :development)
require 'flexmock/test_unit'


require File.dirname(__FILE__) + '/../lib/edl'
require File.dirname(__FILE__) + '/../lib/edl/cutter'
require File.dirname(__FILE__) + '/../lib/edl/grabber'

TRAILER_EDL                 = File.dirname(__FILE__) + '/samples/TRAILER_EDL.edl'
SIMPLE_DISSOLVE             = File.dirname(__FILE__) + '/samples/SIMPLE_DISSOLVE.EDL'
SPLICEME                    = File.dirname(__FILE__) + '/samples/SPLICEME.EDL'
SIMPLE_TIMEWARP             = File.dirname(__FILE__) + '/samples/TIMEWARP.EDL'
SLOMO_TIMEWARP              = File.dirname(__FILE__) + '/samples/TIMEWARP_HALF.EDL'
FORTY_FIVER                 = File.dirname(__FILE__) + '/samples/45S_SAMPLE.EDL'
AVID_REVERSE                = File.dirname(__FILE__) + '/samples/REVERSE.EDL'
SPEEDUP_AND_FADEOUT         = File.dirname(__FILE__) + '/samples/SPEEDUP_AND_FADEOUT.EDL'
SPEEDUP_REVERSE_AND_FADEOUT = File.dirname(__FILE__) + '/samples/SPEEDUP_REVERSE_AND_FADEOUT.EDL'
FCP_REVERSE                 = File.dirname(__FILE__) + '/samples/FCP_REVERSE.EDL'
PLATES                      = File.dirname(__FILE__) + '/samples/PLATES.EDL'
KEY                         = File.dirname(__FILE__) + '/samples/KEY_TRANSITION.EDL'
CLIP_NAMES                  = File.dirname(__FILE__) + '/samples/REEL_IS_CLIP.txt'

class String
  def tc(fps = Timecode::DEFAULT_FPS)
    Timecode.parse(self, fps)
  end
end

class EDLTest < Test::Unit::TestCase
  
  def assert_zero(v, message = "Should be zero")
    assert v.zero?, message
  end
  
context "An Event" do
  should "support hash initialization" do
    evt = EDL::Event.new(:src_start_tc => "01:00:00:00".tc)
    assert_equal "01:00:00:00".tc, evt.src_start_tc
  end

  should "support block initialization" do
    evt = EDL::Event.new do | e | 
      e.src_start_tc = "01:00:00:04".tc
    end
    assert_equal "01:00:00:04".tc, evt.src_start_tc 
  end

  should "respond to ends_with_transition? with false if outgoing_transition_duration is zero" do
    evt = EDL::Event.new
    evt.outgoing_transition_duration = 0
    assert !evt.ends_with_transition?
  end

  should "respond to ends_with_transition? with true if outgoing_transition_duration set above zero" do
    evt = EDL::Event.new
    evt.outgoing_transition_duration = 24
    assert evt.ends_with_transition?
  end

  should "respond to has_timewarp? with false if no timewarp assigned" do
    evt = EDL::Event.new(:timewarp => nil)
    assert !evt.has_timewarp?
  end

  should "respond to has_timewarp? with true if a timewarp  is assigned" do
    evt = EDL::Event.new(:timewarp => true)
    assert evt.has_timewarp?
  end

  should "report rec_length as a difference of record timecodes" do
    evt = EDL::Event.new(:rec_start_tc => "1h".tc, :rec_end_tc => "1h 10s 2f".tc )
    assert_equal "10s 2f".tc.to_i, evt.rec_length 
  end

  should "report rec_length_with_transition as a difference of record timecodes if no transition set" do
    evt = EDL::Event.new(:rec_start_tc => "1h".tc, :rec_end_tc => "1h 10s 2f".tc, :outgoing_transition_duration => 0)
    assert_equal "10s 2f".tc.to_i, evt.rec_length_with_transition
  end

  should "add transition length to rec_length_with_transition if a transition is set" do
    evt = EDL::Event.new(:rec_start_tc => "1h".tc, :rec_end_tc => "1h 10s 2f".tc, :outgoing_transition_duration => 10)
    assert_equal "10s 2f".tc.to_i + 10, evt.rec_length_with_transition
  end

  should "return a default array for comments" do
    assert_kind_of Enumerable, EDL::Event.new.comments
  end

  should "respond false to has_transition? if incoming transition is set" do
    assert !EDL::Event.new(:transition => nil).has_transition?
  end

  should "respond true to has_transition? if incoming transition is set" do
    assert EDL::Event.new(:transition => true).has_transition?
  end

  should "respond true to black? if reel is BL" do
    assert EDL::Event.new(:reel => "BL").black?
    assert !EDL::Event.new(:reel => "001").black?
  end

  should "respond true to generator? if reel is BL or AX" do
    assert EDL::Event.new(:reel => "BL").generator?
    assert EDL::Event.new(:reel => "AX").generator?
    assert !EDL::Event.new(:reel => "001").generator?
  end

  should "report src_length as rec_length_with_transition" do
    e = EDL::Event.new(:rec_start_tc => "2h".tc,  :rec_end_tc => "2h 2s".tc)
    assert_equal "2s".tc.to_i, e.src_length 
  end

  should "support line_number" do
    assert_nil EDL::Event.new.line_number
    assert_equal 3, EDL::Event.new(:line_number => 3).line_number
  end

  should "support capture_length as an alias to src_length" do
    tw = flexmock
    tw.should_receive(:actual_length_of_source).and_return(:something)
    e = EDL::Event.new(:timewarp => tw)
    assert_equal e.capture_length, e.src_length 
  end

  should "delegate src_length to the timewarp if it is there" do
    tw = flexmock
    tw.should_receive(:actual_length_of_source).and_return(:something).once
    e = EDL::Event.new(:timewarp => tw)
    assert_equal :something, e.src_length 
  end

  should "report reverse? and reversed? based on the timewarp" do
    e = EDL::Event.new(:timewarp => nil)
    assert !e.reverse?
    assert !e.reversed?

    tw = flexmock
    tw.should_receive(:reverse?).and_return(true)

    e = EDL::Event.new(:timewarp => tw)
    assert e.reverse?
    assert e.reversed?
  end

  should "report speed as 100 percent without a timewarp" do
    e = EDL::Event.new
    assert_equal 100.0, e.speed
  end

  should "consult the timewarp for speed" do
    tw = flexmock
    tw.should_receive(:speed).and_return(:something)

    e = EDL::Event.new(:timewarp => tw)
    assert_equal :something, e.speed
  end

  should "report false for starts_with_transition? if transision is nil" do
    assert !EDL::Event.new.starts_with_transition?
  end

  should "report zero for incoming_transition_duration if transision is nil" do
    assert_zero EDL::Event.new.incoming_transition_duration
  end

  should "report true for starts_with_transition? if transision is not nil" do
    e = EDL::Event.new :transition => true
    assert e.starts_with_transition?
  end

  should "consult the transition for incoming_transition_duration if it's present" do
    tr = flexmock
    tr.should_receive(:duration).and_return(:something)

    e = EDL::Event.new(:transition => tr)
    assert_equal :something, e.incoming_transition_duration
  end

  should "report capture_from_tc as the source start without a timewarp" do
    e = EDL::Event.new(:src_start_tc => "1h".tc)
    assert_equal "1h".tc, e.capture_from_tc
  end

  should "consult the timewarp for capture_from_tc if a timewarp is there" do
    tw = flexmock
    tw.should_receive(:source_used_from).and_return(:something)

    e = EDL::Event.new(:timewarp => tw)
    assert_equal :something, e.capture_from_tc
  end

  should "report capture_to_tc as record length plus transition when no timewarp present" do
    e = EDL::Event.new(:src_end_tc => "1h 10s".tc, :outgoing_transition_duration => 2 )
    assert_equal "1h 10s 2f".tc, e.capture_to_tc
  end

  should "report capture_to_and_including_tc as record length plus transition when no timewarp present" do
    e = EDL::Event.new(:src_end_tc => "1h 10s".tc, :outgoing_transition_duration => 2 )
    assert_equal "1h 10s 1f".tc, e.capture_to_and_including_tc
  end

  should "consult the timewarp for capture_to_tc if timewarp is present" do
    tw = flexmock
    tw.should_receive(:source_used_upto).and_return(:something)

    e = EDL::Event.new(:timewarp => tw)
    assert_equal :something, e.capture_to_tc
  end
end

context "A Parser" do
  should "store the passed framerate" do
    p = EDL::Parser.new(45)
    assert_equal 45, p.fps
  end
  
  should "return matchers tuned with the passed framerate" do
    p = EDL::Parser.new(30)
    matchers = p.get_matchers
    event_matcher = matchers.find{|e| e.is_a?(EDL::EventMatcher) }
    assert_equal 30, event_matcher.fps
  end
  
  should "create a Timecode from stringified elements" do
    elems = ["08", "04", "24", "24"]
    assert_nothing_raised do
      @tc = EDL::Parser.timecode_from_line_elements(elems, 30)
    end
    
    assert_kind_of Timecode, @tc
    assert_equal "08:04:24:24".tc(30), @tc 
    
    assert_zero elems.length
  end
  
  should "parse from a String" do
    p = EDL::Parser.new
    assert_nothing_raised do
      @edl = p.parse File.read(SIMPLE_DISSOLVE)
    end
    
    assert_kind_of EDL::List, @edl
    assert_equal 2, @edl.length
  end

  should "parse from a File/IOish" do
    p = EDL::Parser.new
    assert_nothing_raised do
      @edl = p.parse File.open(SIMPLE_DISSOLVE)
    end
    
    assert_kind_of EDL::List, @edl
    assert_equal 2, @edl.length
  end
    
  should "properly parse a dissolve" do
    # TODO: reformulate
    p = EDL::Parser.new
    @edl = p.parse File.open(SIMPLE_DISSOLVE)
    
    first, second = @edl
    
    assert_kind_of EDL::Event, first
    assert_kind_of EDL::Event, second
    
    assert second.has_transition?
    assert first.ends_with_transition?
    assert !second.ends_with_transition?
    
    no_trans = @edl.without_transitions
    
    assert_equal 2, no_trans.length
    target_tc = (Timecode.parse('01:00:00:00') + 43)
    assert_equal target_tc, no_trans[0].rec_end_tc, 
      "The incoming clip should have been extended by the length of the dissolve"
    
    target_tc = Timecode.parse('01:00:00:00')
    assert_equal target_tc, no_trans[1].rec_start_tc
      "The outgoing clip should have been left in place"
  end
  
  should "return a spliced EDL if the sources allow" do
    @spliced = EDL::Parser.new.parse(File.open(SPLICEME)).spliced
    
    assert_equal 1, @spliced.length
    evt = @spliced[0]
    
    assert_equal '06:42:50:18'.tc, evt.src_start_tc
    assert_equal '06:42:52:16'.tc, evt.src_end_tc
  end
  
  should "not apply any Matchers if a match is found" do
    p = EDL::Parser.new
    m1 = flexmock
    m1.should_receive(:matches?).with("plop").once.and_return(true)
    m1.should_receive(:apply).once
    
    flexmock(p).should_receive(:get_matchers).once.and_return([m1, m1])
    result = p.parse("plop")
    assert result.empty?
  end
  
  should "register line numbers of the detected events" do
    p = EDL::Parser.new
    events = p.parse(File.open(SPLICEME))
    
    assert_equal 4, events[0].line_number
    assert_equal 5, events[1].line_number
  end
end

context "A TimewarpMatcher" do
  
  should "not create any extra events when used within a Parser" do
    @edl = EDL::Parser.new.parse(File.open(SIMPLE_TIMEWARP))
    assert_equal 1, @edl.length
  end

  should "properly describe a speedup" do
    clip = EDL::Parser.new.parse(File.open(SIMPLE_TIMEWARP)).pop
    
    tw = clip.timewarp
    
    assert_kind_of EDL::Timewarp, tw
    assert_operator tw.source_used_upto, :>, clip.src_end_tc

    assert_equal clip.src_start_tc, tw.source_used_from
    assert_equal 124, clip.timewarp.actual_length_of_source
    assert !tw.reverse?
  end
  
  should "properly describe a slomo" do
    clip = EDL::Parser.new.parse(File.open(SLOMO_TIMEWARP)).pop

    assert_equal 10, clip.rec_length
    assert_equal 5, clip.src_length
    
    tw = clip.timewarp
    
    assert_operator tw.source_used_upto, :<, clip.src_end_tc

    assert_equal "03:03:19:24".tc, tw.source_used_upto
    
    assert_equal 50, tw.speed_in_percent.to_i
    assert_equal 5, tw.actual_length_of_source
    assert !tw.reverse?
  end

end

context "A reverse timewarp EDL coming from Avid" do
  
  should "be parsed properly" do
    
    clip = EDL::Parser.new.parse(File.open(AVID_REVERSE)).pop
    
    assert_equal 52, clip.rec_length
    
    tw = clip.timewarp
    
    assert_equal -25, tw.actual_framerate.to_i
    assert tw.reverse?
    assert_equal 52, tw.actual_length_of_source
    
    assert_equal 52, clip.src_length, "The src length should be computed the same as its just a reverse"
    assert_equal -100.0, clip.timewarp.speed
  end
end

context "EDL with clip reels in comments" do
  
  should "parse clip names into the reel field" do
    
    clips = EDL::Parser.new.parse(File.open(CLIP_NAMES))
    
  end
end

context "A Final Cut Pro originating reverse" do
  
  should "be interpreted properly" do
    e = EDL::Parser.new.parse(File.open(FCP_REVERSE)).pop
    
    assert_equal 1000, e.rec_length
    assert_equal 1000, e.src_length

    assert_equal "1h".tc, e.rec_start_tc 
    assert_equal "1h 40s".tc, e.rec_end_tc
    
    assert e.reverse?
    assert_not_nil e.timewarp
    
    tw = e.timewarp
    
    assert_equal -100, tw.speed
    assert_equal e.speed, tw.speed
    
    assert_equal "1h".tc, tw.source_used_from 
    assert_equal "1h 40s".tc, tw.source_used_upto
  end
end

# context "An edit with keyer transition" do
#   should "parse correctly" do
#     events = EDL::Parser.new.parse(File.open(KEY))
#     assert_equal 2, events.length
#     flunk "Key transition processing is not reliable yet - no reference"
#   end
# end

context "EventMatcher" do

  EVT_PATTERNS = [
    '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17', 
    '021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05', 
    '022  008C     V     C        08:08:01:23 08:08:02:18 01:00:27:05 01:00:28:00', 
    '023  008C     V     C        08:07:30:02 08:07:30:21 01:00:28:00 01:00:28:19', 
    '024        AX V     C        00:00:00:00 00:00:01:00 01:00:28:19 01:00:29:19', 
    '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19', 
    '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20',
    '002  REDACTED V     C        03:09:00:13 03:09:55:19 01:00:43:12 01:01:38:18',
  ]
  
  should 'handle the event with multiple audio tracks' do
    m = EDL::EventMatcher.new(25)
    
    clip = m.apply([],
      '0004 KASS1 A1234V C        00:00:00:00 00:00:16:06  10:00:41:08 10:00:57:14'
    )
    assert_kind_of EDL::Event, clip
    assert_equal "A1234", clip.track
  end
  
  should "produce an Event" do
    m = EDL::EventMatcher.new(25)
    
    clip = m.apply([],
      '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17'
    )
    
    assert_kind_of EDL::Event, clip
    
    assert_equal "020", clip.num
    assert_equal "008C", clip.reel
    assert_equal "V", clip.track
    
    assert_equal '08:04:24:24'.tc, clip.src_start_tc
    
    assert_equal '08:04:25:19'.tc, clip.src_end_tc 
    assert_equal '01:00:25:22'.tc, clip.rec_start_tc 
    assert_equal '01:00:26:17'.tc, clip.rec_end_tc   
    
    assert_nil clip.transition
    assert_nil clip.timewarp
    assert_zero clip.outgoing_transition_duration
  end
  
  should "produce an Event with dissolve" do
    m = EDL::EventMatcher.new(25)
    
    dissolve = m.apply([],
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
    assert_kind_of EDL::Event, dissolve
    
    assert_equal "025", dissolve.num
    assert_equal 'GEN', dissolve.reel
    assert_equal 'V', dissolve.track
    assert dissolve.has_transition?
    
    tr = dissolve.transition
    
    assert_kind_of EDL::Dissolve, tr
    assert_equal 25, tr.duration
  end
  
  should "produce a vanilla Event with proper source length" do
    # This one has EXACTLY 4 frames of source
    m = EDL::EventMatcher.new(25)
    clip = m.apply([], '001  GEN      V     C        00:01:00:00 00:01:00:04 01:00:00:00 01:00:00:04')
    assert_kind_of EDL::Event, clip
    assert_equal 4, clip.src_length
  end
  
  should "set flag on the previous event in the stack when a dissolve is encountered" do
    m = EDL::EventMatcher.new(25)
    previous_evt = flexmock
    previous_evt.should_receive(:outgoing_transition_duration=).with(25).once
    
    m.apply([previous_evt],
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
  end

  should "generate a Wipe" do
    m = EDL::EventMatcher.new(25)
    wipe = m.apply([],
      '025  GEN      V     W001  025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
    
    tr = wipe.transition
    assert_kind_of EDL::Wipe, tr
    assert_equal 25, tr.duration
    assert_equal '001', tr.smpte_wipe_index
  end
  
  should "match the widest range of patterns" do
    EVT_PATTERNS.each do | pat |
      assert EDL::EventMatcher.new(25).matches?(pat), "EventMatcher should match #{pat}"
    end
  end
  
  should "pass the framerate that it received upon instantiation to the Timecodes being created" do
    
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

context "CommentMatcher" do
  should "match a comment" do
    line = "* COMMENT: PURE BULLSHIT"
    assert EDL::CommentMatcher.new.matches?(line)
  end
  
  should "apply the comment to the last clip on the stack" do
    line = "* COMMENT: PURE BULLSHIT"

    comments = []
    mok_evt = flexmock

    2.times { mok_evt.should_receive(:comments).and_return(comments) }
    2.times { EDL::CommentMatcher.new.apply([mok_evt], line) }

    assert_equal ["* COMMENT: PURE BULLSHIT", "* COMMENT: PURE BULLSHIT"], mok_evt.comments
  end
end

context "FallbackMatcher" do
  should "match anything" do
    line = "SOME"
    assert EDL::FallbackMatcher.new.matches?(line)
    
    line = "OR ANOTHER  "
    assert EDL::FallbackMatcher.new.matches?(line)
  end
  
  should "not match whitespace" do
    line = "\s\s\s\r\n\r"
    assert !EDL::FallbackMatcher.new.matches?(line)
  end
  
  should "append the matched content to comments" do
    e = flexmock
    cmts = []
    e.should_receive(:comments).and_return(cmts)
    
    EDL::FallbackMatcher.new.apply([e], "FOOBAR")
    assert_equal ["FOOBAR"], cmts

    EDL::FallbackMatcher.new.apply([e], "FINAL CUT PRO REEL: 006-I REPLACED BY: 006I")
    assert_equal ["FOOBAR", "FINAL CUT PRO REEL: 006-I REPLACED BY: 006I"], cmts
  end
  
  should "raise an ApplyError if no clip is on the stack" do
    assert_raise(EDL::Matcher::ApplyError) do
     EDL::FallbackMatcher.new.apply([], "FINAL CUT PRO REEL: 006-I REPLACED BY: 006I")
    end
  end
  
end

context "ClipNameMatcher" do
  should "match a clip name" do
    line = "* FROM CLIP NAME:  TAPE_6-10.MOV"
    assert EDL::NameMatcher.new.matches?(line)
  end
  
  should "match a clip name without space after star" do
    line = "*FROM CLIP NAME:  TAPE_6-10.MOV"
    assert EDL::NameMatcher.new.matches?(line)
  end
  
  should "not match a simple comment" do
    line = "* CRAP"
    assert !EDL::NameMatcher.new.matches?(line)
  end
  
  should "apply the name to the last event on the stack" do
    line = "* FROM CLIP NAME:  TAPE_6-10.MOV"

    mok_evt = flexmock
    comments = []
    mok_evt.should_receive(:clip_name=).with('TAPE_6-10.MOV').once
    mok_evt.should_receive(:comments).and_return(comments).once
    
    EDL::NameMatcher.new.apply([mok_evt], line)
    assert_equal ["* FROM CLIP NAME:  TAPE_6-10.MOV"], comments
  end
  
end

context "EffectMatcher" do
  should "not match a simple comment" do
    line = "* STUFF"
    assert !EDL::EffectMatcher.new.matches?(line)
  end

  should "match a dissolve name" do
    line = "* EFFECT NAME: CROSS DISSOLVE"
    assert EDL::EffectMatcher.new.matches?(line)
  end

  should "match a dissolve name without space after the asterisk" do
    line = "*EFFECT NAME: CROSS DISSOLVE"
    assert EDL::EffectMatcher.new.matches?(line)
  end

  should "apply the effect name to the transition of the last event on the stack" do
    line = "* EFFECT NAME: CROSS DISSOLVE"
    mok_evt, mok_transition = flexmock, flexmock
    cmt = []
    
    mok_evt.should_receive(:transition).once.and_return(mok_transition)
    mok_evt.should_receive(:comments).once.and_return(cmt)

    mok_transition.should_receive(:effect=).with("CROSS DISSOLVE").once
    
    EDL::EffectMatcher.new.apply([mok_evt], line)
    
    assert_equal ["* EFFECT NAME: CROSS DISSOLVE"], cmt
  end

end

context "A complex EDL passed via Parser" do
  should "parse without errors" do
    assert_nothing_raised { EDL::Parser.new.parse(File.open(FORTY_FIVER)) }
  end

  should "parse the EDL with \\r line breaks properly" do
    evts = EDL::Parser.new.parse(File.read(PLATES))
    assert_equal 3, evts.length
  end

  # TODO: this does not belong here
  should "be properly rewritten from zero" do
    complex = EDL::Parser.new.parse(File.open(FORTY_FIVER))
    from_zero = complex.from_zero
  
    assert_equal complex.length, from_zero.length, "Should have the same number of events"
  
    assert_zero from_zero[0].rec_start_tc
    assert_equal '00:00:42:16'.tc, from_zero[-1].rec_end_tc 
  end
end

context "A FinalCutPro speedup with fade at the end" do
  should "be parsed cleanly" do
    list = EDL::Parser.new.parse(File.open(SPEEDUP_AND_FADEOUT))
  
    assert_equal 2, list.length
    
    first_evt = list[0]
  
    tw = first_evt.timewarp
    assert_kind_of EDL::Timewarp, tw
  
    assert_equal 689, first_evt.rec_length
    assert_equal 714, first_evt.rec_length_with_transition
    
    assert_equal 1000, tw.actual_length_of_source
    assert_equal 140, tw.speed
    
    assert_equal 1000, first_evt.src_length
  
    assert_equal "01:00:00:00", first_evt.capture_from_tc.to_s
    assert_equal "01:00:40:00", first_evt.capture_to_tc.to_s
  end
end
  
context "In the trailer EDL the event 4" do
  should "not have too many comments" do
    evts = EDL::Parser.new.parse(File.open(TRAILER_EDL))
    evt = evts[6]
    assert_equal 5, evt.comments.length
  end
end

context "A FinalCutPro speedup and reverse with fade at the end" do
  should "parse cleanly" do
    first_evt = EDL::Parser.new.parse(File.open(SPEEDUP_REVERSE_AND_FADEOUT)).shift

    assert first_evt.reverse?
    
    assert_equal 689, first_evt.rec_length
    assert_equal 714, first_evt.rec_length_with_transition
    
    tw = first_evt.timewarp
    
    assert_equal "1h 1f".tc, tw.source_used_from
    assert_equal "1h 40s".tc, tw.source_used_upto
  end
end

end
