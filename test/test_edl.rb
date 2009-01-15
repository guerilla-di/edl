require File.dirname(__FILE__) + '/../lib/edl'
require File.dirname(__FILE__) + '/../lib/edl/cutter'
require File.dirname(__FILE__) + '/../lib/edl/grabber'

require 'rubygems'
require 'test/unit'
require 'test/spec'
require 'flexmock'
require 'flexmock/test_unit'

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

class String
  def tc(fps = Timecode::DEFAULT_FPS)
    Timecode.parse(self, fps)
  end
end

context "An Event should" do
  specify "define the needed attributes" do
    evt = EDL::Event.new
    %w(  num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc ).each do | em |
      evt.should.respond_to em
    end
  end
  
  specify "support hash initialization" do
    evt = EDL::Event.new(:src_start_tc => "01:00:00:00".tc)
    evt.src_start_tc.should.equal "01:00:00:00".tc
  end

  specify "support block initialization" do
    evt = EDL::Event.new do | e | 
      e.src_start_tc = "01:00:00:04".tc
    end
    evt.src_start_tc.should.equal "01:00:00:04".tc
  end

  specify "respond to ends_with_transition? with false if outgoing_transition_duration is zero" do
    evt = EDL::Event.new
    evt.outgoing_transition_duration = 0
    evt.ends_with_transition?.should.equal false
  end
  
  specify "respond to ends_with_transition? with true if outgoing_transition_duration set above zero" do
    evt = EDL::Event.new
    evt.outgoing_transition_duration = 24
    evt.ends_with_transition?.should.equal true
  end
  
  specify "respond to has_timewarp? with false if no timewarp assigned" do
    evt = EDL::Event.new(:timewarp => nil)
    evt.has_timewarp?.should.equal false
  end

  specify "respond to has_timewarp? with true if a timewarp  is assigned" do
    evt = EDL::Event.new(:timewarp => true)
    evt.has_timewarp?.should.equal true
  end
  
  specify "report rec_length as a difference of record timecodes" do
    evt = EDL::Event.new(:rec_start_tc => "1h".tc, :rec_end_tc => "1h 10s 2f".tc )
    evt.rec_length.should.equal "10s 2f".tc.to_i
  end

  specify "report rec_length_with_transition as a difference of record timecodes if no transition set" do
    evt = EDL::Event.new(:rec_start_tc => "1h".tc, :rec_end_tc => "1h 10s 2f".tc, :outgoing_transition_duration => 0)
    evt.rec_length_with_transition.should.equal "10s 2f".tc.to_i
  end

  specify "add transition length to rec_length_with_transition if a transition is set" do
    evt = EDL::Event.new(:rec_start_tc => "1h".tc, :rec_end_tc => "1h 10s 2f".tc, :outgoing_transition_duration => 10)
    evt.rec_length_with_transition.should.equal("10s 2f".tc.to_i + 10)
  end

  specify "return a default array for comments" do
    EDL::Event.new.comments.should.be.kind_of Enumerable
  end

  specify "respond false to has_transition? if incoming transition is set" do
    EDL::Event.new(:transition => nil).has_transition?.should.equal false
  end

  specify "respond true to has_transition? if incoming transition is set" do
    EDL::Event.new(:transition => true).has_transition?.should.equal true
  end
  
  specify "respond true to black? if reel is BL" do
    EDL::Event.new(:reel => "BL").should.black
    EDL::Event.new(:reel => "001").should.not.black
  end

  specify "respond true to generator? if reel is BL or AX" do
    EDL::Event.new(:reel => "BL").should.generator
    EDL::Event.new(:reel => "AX").should.generator
    EDL::Event.new(:reel => "001").should.not.generator
  end
  
  specify "report src_length as rec_length_with_transition" do
    e = EDL::Event.new(:rec_start_tc => "2h".tc,  :rec_end_tc => "2h 2s".tc)
    e.src_length.should.equal "2s".tc.to_i 
  end
  
  specify "support capture_length as an alias to src_length" do
    tw = flexmock
    tw.should_receive(:actual_length_of_source).and_return(:something)
    e = EDL::Event.new(:timewarp => tw)
    e.src_length.should.equal e.capture_length
  end
  
  specify "delegate src_length to the timewarp if it is there" do
    tw = flexmock
    tw.should_receive(:actual_length_of_source).and_return(:something).once
    e = EDL::Event.new(:timewarp => tw)
    e.src_length.should.equal :something 
  end
  
  specify "report reverse? and reversed? based on the timewarp" do
    e = EDL::Event.new(:timewarp => nil)
    e.should.not.be.reverse
    e.should.not.be.reversed

    tw = flexmock
    tw.should_receive(:reverse?).and_return(true)

    e = EDL::Event.new(:timewarp => tw)
    e.should.be.reverse
    e.should.be.reversed
  end
  
  specify "report speed as 100 percent without a timewarp" do
    e = EDL::Event.new
    e.speed.should.equal 100
  end

  specify "consult the timewarp for speed" do
    tw = flexmock
    tw.should_receive(:speed).and_return(:something)

    e = EDL::Event.new(:timewarp => tw)
    e.speed.should.equal :something
  end

  
  specify "report capture_from_tc as the source start without a timewarp" do
    e = EDL::Event.new(:src_start_tc => "1h".tc)
    e.capture_from_tc.should.equal "1h".tc
  end
  
  specify "consult the timewarp for capture_from_tc if a timewarp is there" do
    tw = flexmock
    tw.should_receive(:source_used_from).and_return(:something)
    
    e = EDL::Event.new(:timewarp => tw)
    e.capture_from_tc.should.equal :something
  end

  specify "report capture_to_tc as record length plus transition when no timewarp present" do
    e = EDL::Event.new(:src_end_tc => "1h 10s".tc, :outgoing_transition_duration => 2 )
    e.capture_to_tc.should.equal "1h 10s 2f".tc
  end

  specify "consult the timewarp for capture_to_tc if timewarp is present" do
    tw = flexmock
    tw.should_receive(:source_used_upto).and_return(:something)

    e = EDL::Event.new(:timewarp => tw)
    e.capture_to_tc.should.equal :something
  end


end

context "A Parser should" do
  
  specify "store the passed framerate" do
    p = EDL::Parser.new(45)
    p.should.respond_to :fps
    p.fps.should.equal 45
  end
  
  specify "return matchers tuned with the passed framerate" do
    p = EDL::Parser.new(30)
    matchers = p.get_matchers
    event_matcher = matchers.find{|e| e.is_a?(EDL::EventMatcher) }
    event_matcher.fps.should.equal 30
  end
  
  specify "create a Timecode from stringified elements" do
    elems = ["08", "04", "24", "24"]
    lambda{ @tc = EDL::Parser.timecode_from_line_elements(elems, 30) }.should.not.raise
    
    @tc.should.be.kind_of Timecode
    @tc.should.equal "08:04:24:24".tc(30)
    
    elems.length.should.equal 0
  end
  
  specify "parse from a String" do
    p = EDL::Parser.new
    lambda{ @edl = p.parse File.read(SIMPLE_DISSOLVE) }.should.not.raise
    
    @edl.should.be.kind_of EDL::List
    @edl.length.should.equal 2
  end

  specify "parse from a File/IOish" do
    p = EDL::Parser.new
    lambda{ @edl = p.parse File.open(SIMPLE_DISSOLVE) }.should.not.raise
    
    @edl.should.be.kind_of EDL::List
    @edl.length.should.equal 2
  end
    
  specify "properly parse a dissolve" do
    # TODO: reformulate
    p = EDL::Parser.new
    lambda{ @edl = p.parse File.open(SIMPLE_DISSOLVE) }.should.not.raise

    @edl.should.be.kind_of EDL::List
    @edl.length.should.equal 2
    
    first, second = @edl
    first.should.be.kind_of EDL::Event
    second.should.be.kind_of EDL::Event
    
    second.has_transition?.should.equal true
    first.ends_with_transition?.should.equal true
    second.ends_with_transition?.should.equal false
    
    no_trans = @edl.without_transitions
    
    assert_equal 2, no_trans.length
    target_tc = (Timecode.parse('01:00:00:00') + 43)
    assert_equal target_tc, no_trans[0].rec_end_tc, 
      "The incoming clip should have been extended by the length of the dissolve"
    
    target_tc = Timecode.parse('01:00:00:00')
    assert_equal target_tc, no_trans[1].rec_start_tc
      "The outgoing clip should have been left in place"
  end
  
  specify "return a spliced EDL if the sources allow" do
    lambda{ @spliced = EDL::Parser.new.parse(File.open(SPLICEME)).spliced }.should.not.raise

    @spliced.length.should.equal 1
    @spliced[0].src_start_tc.should.equal '06:42:50:18'.tc
    @spliced[0].src_end_tc.should.equal   '06:42:52:16'.tc
  end
end

context "A TimewarpMatcher should" do
  
  specify "not create any extra events when used within a Parser" do
    @edl = EDL::Parser.new.parse(File.open(SIMPLE_TIMEWARP))
    @edl.length.should.equal 1
  end

  specify "properly describe a speedup" do
    clip = EDL::Parser.new.parse(File.open(SIMPLE_TIMEWARP)).pop
    
    tw = clip.timewarp
    
    tw.should.be.kind_of EDL::Timewarp
    tw.source_used_upto.should.be > clip.src_end_tc

    tw.source_used_from.should.equal clip.src_start_tc
    clip.timewarp.actual_length_of_source.should.equal 124
    
    tw.reverse?.should.be false
  end
  
  specify "properly describe a slomo" do
    clip = EDL::Parser.new.parse(File.open(SLOMO_TIMEWARP)).pop

    clip.rec_length.should.equal 10
    clip.src_length.should.equal 5
    
    tw = clip.timewarp
    tw.should.be.kind_of EDL::Timewarp

    tw.source_used_upto.should.be < clip.src_end_tc
    tw.source_used_upto.should.equal "03:03:19:24".tc
    tw.speed_in_percent.to_i.should.equal 50
    tw.actual_length_of_source.should.equal 5
    
    tw.should.not.be.reverse
  end

end

context "A reverse timewarp EDL coming from Avid should" do
  
  specify "be parsed properly" do
    
    clip = EDL::Parser.new.parse(File.open(AVID_REVERSE)).pop
    
    clip.rec_length.should.equal 52
    
    tw = clip.timewarp
    tw.actual_framerate.to_i.should.equal -25
    
    tw.should.be.reverse
    
    tw.actual_length_of_source.should.equal 52
    
    assert_equal 52, clip.src_length, "The src length should be computed the same as its just a reverse"
    assert_equal -100.0, clip.timewarp.speed
  end
end

context "A Final Cut Pro originating reverse should" do
  specify "be interpreted properly" do
    e = EDL::Parser.new.parse(File.open(FCP_REVERSE)).pop
    
    e.rec_length.should.equal 1000
    e.src_length.should.equal 1000

    e.rec_start_tc.should.equal "1h".tc
    e.rec_end_tc.should.equal "1h 40s".tc
    
    e.should.be.reverse
    e.timewarp.should.not.be nil
    
    tw = e.timewarp
    tw.source_used_from.should.equal "1h".tc
    tw.source_used_upto.should.equal "1h 40s".tc
  end
end

context "EventMatcher should" do

  EVT_PATTERNS = [
    '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17', 
    '021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05', 
    '022  008C     V     C        08:08:01:23 08:08:02:18 01:00:27:05 01:00:28:00', 
    '023  008C     V     C        08:07:30:02 08:07:30:21 01:00:28:00 01:00:28:19', 
    '024        AX V     C        00:00:00:00 00:00:01:00 01:00:28:19 01:00:29:19', 
    '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19', 
    '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20',
  ]

  specify "produce an Event" do
    m = EDL::EventMatcher.new(25)
    
    clip = m.apply([],
      '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17'
    )
    
    clip.should.be.kind_of EDL::Event
    
    clip.num.should.equal "020"
    clip.reel.should.equal "008C"
    clip.track.should.equal "V"
    
    clip.src_start_tc.should.equal '08:04:24:24'.tc
    
    clip.src_end_tc.should.equal   '08:04:25:19'.tc
    clip.rec_start_tc.should.equal '01:00:25:22'.tc
    clip.rec_end_tc.should.equal   '01:00:26:17'.tc
    
    clip.transition.should.be nil
    clip.timewarp.should.be nil
    clip.outgoing_transition_duration.should.be.zero
    
  end
  
  specify "produce an Event with dissolve" do
    m = EDL::EventMatcher.new(25)
    
    dissolve = m.apply([],
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
    dissolve.should.be.kind_of EDL::Event
    
    dissolve.num.should.equal "025"
    dissolve.reel.should.equal "GEN"
    dissolve.track.should.equal "V"
    
    dissolve.should.be.has_transition
    
    tr = dissolve.transition
    
    tr.should.be.kind_of EDL::Dissolve
    tr.duration.should.equal 25
  end
  
  specify "set flag on the previous event in the stack when a dissolve is encountered" do
    m = EDL::EventMatcher.new(25)
    previous_evt = flexmock
    previous_evt.should_receive(:outgoing_transition_duration=).with(25).once
    
    m.apply([previous_evt],
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
  end

  specify "generate a Wipe" do
    m = EDL::EventMatcher.new(25)
    wipe = m.apply([],
      '025  GEN      V     W001  025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
    
    tr = wipe.transition
    tr.should.be.kind_of EDL::Wipe
    tr.duration.should.equal 25
    tr.smpte_wipe_index.should.equal '001'
  end
  
  specify "match the widest range of patterns" do
    EVT_PATTERNS.each do | pat |
      assert EDL::EventMatcher.new(25).matches?(pat), "EventMatcher should match #{pat}"
    end
  end
  
  specify "pass the framerate that it received upon instantiation to the Timecodes being created" do
    
    m = EDL::EventMatcher.new(30)
    clip = m.apply([],
      '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17'
    )
    clip.rec_start_tc.fps.should.equal 30
    clip.rec_end_tc.fps.should.equal 30
    clip.src_start_tc.fps.should.equal 30
    clip.src_end_tc.fps.should.equal 30
  end
end

context "CommentMatcher should" do
  specify "match a comment" do
    line = "* COMMENT: PURE BULLSHIT"
    assert EDL::CommentMatcher.new.matches?(line)
  end
  
  specify "apply the comment to the last clip on the stack" do
    line = "* COMMENT: PURE BULLSHIT"

    comments = []
    mok_evt = flexmock

    2.times { mok_evt.should_receive(:comments).and_return(comments) }
    2.times { EDL::CommentMatcher.new.apply([mok_evt], line) }

    mok_evt.comments.should.equal ["COMMENT: PURE BULLSHIT", "COMMENT: PURE BULLSHIT"] 
  end
end

context "ClipNameMatcher should" do
  specify "match a clip name" do
    line = "* FROM CLIP NAME:  TAPE_6-10.MOV"
    EDL::NameMatcher.new.matches?(line).should.equal true
  end
  
  specify "not match a simple comment" do
    line = "* CRAP"
    EDL::NameMatcher.new.matches?(line).should.equal false
  end
  
  specify "apply the name to the last event on the stack" do
    line = "* FROM CLIP NAME:  TAPE_6-10.MOV"

    mok_evt = flexmock
    comments = []
    mok_evt.should_receive(:clip_name=).with('TAPE_6-10.MOV').once
    mok_evt.should_receive(:comments).and_return(comments).once
    
    EDL::NameMatcher.new.apply([mok_evt], line)
    comments.should.equal ["FROM CLIP NAME:  TAPE_6-10.MOV"] 
  end
  
end

context "EffectMatcher should" do
  specify "not match a simple comment" do
    line = "* STUFF"
    EDL::EffectMatcher.new.matches?(line).should.equal false
  end

  specify "match a dissolve name" do
    line = "* EFFECT NAME: CROSS DISSOLVE"
    EDL::EffectMatcher.new.matches?(line).should.equal true
  end

  specify "apply the effect name to the transition of the last event on the stack" do
    line = "* EFFECT NAME: CROSS DISSOLVE"
    mok_evt, mok_transition = flexmock, flexmock
    cmt = []
    
    mok_evt.should_receive(:transition).once.and_return(mok_transition)
    mok_evt.should_receive(:comments).once.and_return(cmt)

    mok_transition.should_receive(:effect=).with("CROSS DISSOLVE").once
    
    EDL::EffectMatcher.new.apply([mok_evt], line)
    
    cmt.should.equal ["EFFECT NAME: CROSS DISSOLVE"]
  end

end

context "A complex EDL passed via Parser should" do
  specify "parse without errors" do
    assert_nothing_raised { EDL::Parser.new.parse(File.open(FORTY_FIVER)) }
  end
  
  # TODO: this does not belong here
  specify "be properly rewritten from zero" do
    complex = EDL::Parser.new.parse(File.open(FORTY_FIVER))
    from_zero = complex.from_zero
    
    # Should have the same number of events
    from_zero.length.should.equal complex.length
    
    from_zero[0].rec_start_tc.should.be.zero
    from_zero[-1].rec_end_tc.should.equal '00:00:42:16'.tc
  end
end

context "A FinalCutPro speedup with fade at the end should" do
  specify "be parsed cleanly" do
    list = EDL::Parser.new.parse(File.open(SPEEDUP_AND_FADEOUT))
    
    list.length.should.equal 2
    
    first_evt = list[0]
    
    tw = first_evt.timewarp
    tw.should.be.kind_of EDL::Timewarp
    
    first_evt.rec_length.should.equal 689
    first_evt.rec_length_with_transition.should.equal 714
    
    tw.actual_length_of_source.should.equal 1000
    tw.speed.should.equal 140
    
    assert_equal 1000, first_evt.src_length
    
    assert_equal "01:00:00:00", first_evt.capture_from_tc.to_s
    assert_equal "01:00:40:00", first_evt.capture_to_tc.to_s
  end
end

context "A FinalCutPro speedup and reverse with fade at the end should" do
  specify "parse cleanly" do
    first_evt = EDL::Parser.new.parse(File.open(SPEEDUP_REVERSE_AND_FADEOUT)).shift
    
    first_evt.should.be.reverse
    
    first_evt.rec_length.should.equal 689
    first_evt.rec_length_with_transition.should.equal 714 
    
    tw = first_evt.timewarp
    tw.source_used_from.should.equal "1h 1f".tc
    tw.source_used_upto.should.equal "1h 40s".tc
  end
end