# frozen_string_literal: true

TRAILER_EDL                 = 'spec/fixtures/files/TRAILER_EDL.edl'
SIMPLE_DISSOLVE             = 'spec/fixtures/files/SIMPLE_DISSOLVE.EDL'
SPLICEME                    = 'spec/fixtures/files/SPLICEME.EDL'
SIMPLE_TIMEWARP             = 'spec/fixtures/files/TIMEWARP.EDL'
SLOMO_TIMEWARP              = 'spec/fixtures/files/TIMEWARP_HALF.EDL'
FORTY_FIVER                 = 'spec/fixtures/files/45S_SAMPLE.EDL'
AVID_REVERSE                = 'spec/fixtures/files/REVERSE.EDL'
SPEEDUP_AND_FADEOUT         = 'spec/fixtures/files/SPEEDUP_AND_FADEOUT.EDL'
SPEEDUP_REVERSE_AND_FADEOUT = 'spec/fixtures/files/SPEEDUP_REVERSE_AND_FADEOUT.EDL'
FCP_REVERSE                 = 'spec/fixtures/files/FCP_REVERSE.EDL'
PLATES                      = 'spec/fixtures/files/PLATES.EDL'
KEY                         = 'spec/fixtures/files/KEY_TRANSITION.EDL'
CLIP_NAMES                  = 'spec/fixtures/files/REEL_IS_CLIP.txt'
MIXED_LINEBREAKS            = 'spec/fixtures/files/edl_mixed_line_endings.edl'

class String
  def tc(fps = Timecode::DEFAULT_FPS)
    Timecode.parse(self, fps)
  end
end

describe EDL do
  describe 'An Event' do
    it 'support hash initialization' do
      evt = EDL::Event.new(src_start_tc: '01:00:00:00'.tc)
      expect('01:00:00:00'.tc).to eq evt.src_start_tc
    end

    it 'support block initialization' do
      evt = EDL::Event.new do |e|
        e.src_start_tc = '01:00:00:04'.tc
      end
      expect('01:00:00:04'.tc).to eq evt.src_start_tc
    end

    it 'respond to ends_with_transition? with false if outgoing_transition_duration is zero' do
      evt = EDL::Event.new
      evt.outgoing_transition_duration = 0
      expect(evt.ends_with_transition?).to be_falsey
    end

    it 'respond to ends_with_transition? with true if outgoing_transition_duration set above zero' do
      evt = EDL::Event.new
      evt.outgoing_transition_duration = 24
      expect(evt.ends_with_transition?).to be_truthy
    end

    it 'respond to has_timewarp? with false if no timewarp assigned' do
      evt = EDL::Event.new(timewarp: nil)
      expect(evt.has_timewarp?).to be_falsey
    end

    it 'respond to has_timewarp? with true if a timewarp  is assigned' do
      evt = EDL::Event.new(timewarp: true)
      expect(evt.has_timewarp?).to be_truthy
    end

    it 'report rec_length as a difference of record timecodes' do
      evt = EDL::Event.new(rec_start_tc: '1h'.tc, rec_end_tc: '1h 10s 2f'.tc)
      expect('10s 2f'.tc.to_i).to eq evt.rec_length
    end

    it 'report rec_length_with_transition as a difference of record timecodes if no transition set' do
      evt = EDL::Event.new(rec_start_tc: '1h'.tc, rec_end_tc: '1h 10s 2f'.tc, outgoing_transition_duration: 0)
      expect('10s 2f'.tc.to_i).to eq evt.rec_length_with_transition
    end

    it 'add transition length to rec_length_with_transition if a transition is set' do
      evt = EDL::Event.new(rec_start_tc: '1h'.tc, rec_end_tc: '1h 10s 2f'.tc, outgoing_transition_duration: 10)
      expect('10s 2f'.tc.to_i + 10).to eq evt.rec_length_with_transition
    end

    it 'return a default array for comments' do
      expect(EDL::Event.new.comments).to be_a(Enumerable)
    end

    it 'respond false to has_transition? if incoming transition is set' do
      expect(EDL::Event.new(transition: nil).has_transition?).to be_falsey
    end

    it 'respond true to has_transition? if incoming transition is set' do
      expect(EDL::Event.new(transition: true).has_transition?).to be_truthy
    end

    it 'respond true to black? if reel is BL' do
      expect(EDL::Event.new(reel: 'BL')).to be_black
      expect(EDL::Event.new(reel: '001')).to_not be_black
    end

    it 'respond true to generator? if reel is BL or AX' do
      expect(EDL::Event.new(reel: 'BL')).to be_generator
      expect(EDL::Event.new(reel: 'AX')).to be_generator
      expect(EDL::Event.new(reel: '001')).to_not be_generator
    end

    it 'report src_length as rec_length_with_transition' do
      e = EDL::Event.new(rec_start_tc: '2h'.tc, rec_end_tc: '2h 2s'.tc)
      expect('2s'.tc.to_i).to eq e.src_length
    end

    it 'support line_number' do
      expect(EDL::Event.new.line_number).to be_nil
      expect(3).to eq EDL::Event.new(line_number: 3).line_number
    end

    it 'support capture_length as an alias to src_length' do
      tw = double
      expect(tw).to receive(:actual_length_of_source).twice.and_return(:something)
      e = EDL::Event.new(timewarp: tw)
      expect(e.capture_length).to eq e.src_length
    end

    it 'delegate src_length to the timewarp if it is there' do
      tw = double
      expect(tw).to receive(:actual_length_of_source).and_return(:something)
      e = EDL::Event.new(timewarp: tw)
      expect(:something).to eq e.src_length
    end

    it 'report reverse? and reversed? based on the timewarp' do
      e = EDL::Event.new(timewarp: nil)
      expect(e).to_not be_reverse
      expect(e).to_not be_reversed

      tw = double
      expect(tw).to receive(:reverse?).twice.and_return(true)

      e = EDL::Event.new(timewarp: tw)
      expect(e).to be_reverse
      expect(e).to be_reversed
    end

    it 'report speed as 100 percent without a timewarp' do
      e = EDL::Event.new
      expect(100.0).to eq e.speed
    end

    it 'consult the timewarp for speed' do
      tw = double
      expect(tw).to receive(:speed).and_return(:something)

      e = EDL::Event.new(timewarp: tw)
      expect(:something).to eq e.speed
    end

    it 'report false for starts_with_transition? if transision is nil' do
      expect(EDL::Event.new.starts_with_transition?).to be_falsey
    end

    it 'report zero for incoming_transition_duration if transision is nil' do
      expect(EDL::Event.new.incoming_transition_duration).to be_zero
    end

    it 'report true for starts_with_transition? if transision is not nil' do
      e = EDL::Event.new transition: true
      expect(e.starts_with_transition?).to be_truthy
    end

    it "consult the transition for incoming_transition_duration if it's present" do
      tr = double
      expect(tr).to receive(:duration).and_return(:something)

      e = EDL::Event.new(transition: tr)
      expect(:something).to eq e.incoming_transition_duration
    end

    it 'report capture_from_tc as the source start without a timewarp' do
      e = EDL::Event.new(src_start_tc: '1h'.tc)
      expect('1h'.tc).to eq e.capture_from_tc
    end

    it 'consult the timewarp for capture_from_tc if a timewarp is there' do
      tw = double
      expect(tw).to receive(:source_used_from).and_return(:something)

      e = EDL::Event.new(timewarp: tw)
      expect(:something).to eq e.capture_from_tc
    end

    it 'report capture_to_tc as record length plus transition when no timewarp present' do
      e = EDL::Event.new(src_end_tc: '1h 10s'.tc, outgoing_transition_duration: 2)
      expect('1h 10s 2f'.tc).to eq e.capture_to_tc
    end

    it 'report capture_to_and_including_tc as record length plus transition when no timewarp present' do
      e = EDL::Event.new(src_end_tc: '1h 10s'.tc, outgoing_transition_duration: 2)
      expect('1h 10s 1f'.tc).to eq e.capture_to_and_including_tc
    end

    it 'consult the timewarp for capture_to_tc if timewarp is present' do
      tw = double
      expect(tw).to receive(:source_used_upto).and_return(:something)

      e = EDL::Event.new(timewarp: tw)
      expect(:something).to eq e.capture_to_tc
    end
  end

  describe 'A Parser' do
    it 'store the passed framerate' do
      p = EDL::Parser.new(45)
      expect(45).to eq p.fps
    end

    it 'return matchers tuned with the passed framerate' do
      p = EDL::Parser.new(30)
      matchers = p.get_matchers
      event_matcher = matchers.find { |e| e.is_a?(EDL::EventMatcher) }
      expect(30).to eq event_matcher.fps
    end

    it 'create a Timecode from stringified elements' do
      elems = %w[08 04 24 24]
      expect do
        @tc = EDL::Parser.timecode_from_line_elements(elems, 30)
      end.to_not raise_error

      expect(@tc).to be_a(Timecode)
      expect('08:04:24:24'.tc(30)).to eq @tc

      expect(elems).to be_empty
    end

    it 'parse from a String' do
      p = EDL::Parser.new
      expect do
        @edl = p.parse File.read(SIMPLE_DISSOLVE)
      end.to_not raise_error

      expect(@edl).to be_a(EDL::List)
      expect(@edl.length).to eq 2
    end

    it 'parse from a File/IOish' do
      p = EDL::Parser.new
      expect do
        @edl = p.parse File.open(SIMPLE_DISSOLVE)
      end.to_not raise_error

      expect(@edl).to be_a(EDL::List)
      expect(@edl.length).to eq 2
    end

    it 'properly parse a dissolve' do
      # TODO: reformulate
      p = EDL::Parser.new
      @edl = p.parse File.open(SIMPLE_DISSOLVE)

      first, second = @edl

      expect(first).to be_a(EDL::Event)
      expect(second).to be_a(EDL::Event)

      expect(second.has_transition?).to be_truthy
      expect(first.ends_with_transition?).to be_truthy
      expect(second.ends_with_transition?).to be_falsey

      no_trans = @edl.without_transitions

      expect(2).to eq no_trans.length
      target_tc = (Timecode.parse('01:00:00:00') + 43)
      expect(target_tc).to eq(no_trans[0].rec_end_tc),
                           'The iitshould have been extended by the length of the dissolve'

      target_tc = Timecode.parse('01:00:00:00')
      expect(target_tc).to eq no_trans[1].rec_start_tc
      'The oitshould have been left in place'
    end

    it 'return a spliced EDL if the sources allow' do
      @spliced = EDL::Parser.new.parse(File.open(SPLICEME)).spliced

      expect(1).to eq @spliced.length
      evt = @spliced[0]

      expect('06:42:50:18'.tc).to eq evt.src_start_tc
      expect('06:42:52:16'.tc).to eq evt.src_end_tc
    end

    it 'not apply any Matchers if a match is found' do
      p = EDL::Parser.new
      m1 = double
      expect(m1).to receive(:matches?).with('plop').and_return(true)
      expect(m1).to receive(:apply)

      expect(p).to receive(:get_matchers).and_return([m1, m1])
      result = p.parse('plop')
      expect(result).to be_empty
    end

    it 'register line numbers of the detected events' do
      p = EDL::Parser.new
      events = p.parse(File.open(SPLICEME))

      expect(4).to eq events[0].line_number
      expect(5).to eq events[1].line_number
    end
  end

  describe 'A TimewarpMatcher' do
    it 'not create any extra events when used within a Parser' do
      @edl = EDL::Parser.new.parse(File.open(SIMPLE_TIMEWARP))
      expect(1).to eq @edl.length
    end

    it 'properly describe a speedup' do
      clip = EDL::Parser.new.parse(File.open(SIMPLE_TIMEWARP)).pop

      tw = clip.timewarp

      expect(tw).to be_a(EDL::Timewarp)
      expect(tw.source_used_upto).to be > clip.src_end_tc

      expect(clip.src_start_tc).to eq tw.source_used_from
      expect(124).to eq clip.timewarp.actual_length_of_source
      expect(tw).to_not be_reverse
    end

    it 'properly describe a slomo' do
      clip = EDL::Parser.new.parse(File.open(SLOMO_TIMEWARP)).pop

      expect(10).to eq clip.rec_length
      expect(5).to eq clip.src_length

      tw = clip.timewarp

      expect(tw.source_used_upto).to be < clip.src_end_tc

      expect('03:03:19:24'.tc).to eq tw.source_used_upto

      expect(50).to eq tw.speed_in_percent.to_i
      expect(5).to eq tw.actual_length_of_source
      expect(tw).to_not be_reverse
    end
  end

  describe 'A reverse timewarp EDL coming from Avid' do
    it 'be parsed properly' do
      clip = EDL::Parser.new.parse(File.open(AVID_REVERSE)).pop

      expect(52).to eq clip.rec_length

      tw = clip.timewarp

      expect(-25).to eq tw.actual_framerate.to_i
      expect(tw).to be_reverse
      expect(52).to eq tw.actual_length_of_source

      expect(-100.0).to eq(clip.timewarp.speed), 'should be computed the same as its just a reverse'
    end
  end

  describe 'EDL with clip reels in comments' do
    it 'parse clip names into the reel field' do
      clips = EDL::Parser.new.parse(File.open(CLIP_NAMES))
      # flunk "This still has to be finalized"
    end
  end

  describe 'A Final Cut Pro originating reverse' do
    it 'be interpreted properly' do
      e = EDL::Parser.new.parse(File.open(FCP_REVERSE)).pop

      expect(1000).to eq e.rec_length
      expect(1000).to eq e.src_length

      expect('1h'.tc).to eq e.rec_start_tc
      expect('1h 40s'.tc).to eq e.rec_end_tc

      expect(e).to be_reverse
      expect(e.timewarp).to_not be_nil

      tw = e.timewarp

      expect(-100).to eq tw.speed
      expect(e.speed).to eq tw.speed

      expect('1h'.tc).to eq tw.source_used_from
      expect('1h 40s'.tc).to eq tw.source_used_upto
    end
  end

  # describe "An edit with keyer transition" do
  #   itould "parse correctly" do
  #     events = EDL::Parser.new.parse(File.open(KEY))
  #     expect(2).to eq events.length
  #     flunk "Key transition processing is not reliable yet - no reference"
  #   end
  # end

  describe 'EventMatcher' do
    EVT_PATTERNS = [
      '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17',
      '021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05',
      '022  008C     V     C        08:08:01:23 08:08:02:18 01:00:27:05 01:00:28:00',
      '023  008C     V     C        08:07:30:02 08:07:30:21 01:00:28:00 01:00:28:19',
      '024        AX V     C        00:00:00:00 00:00:01:00 01:00:28:19 01:00:29:19',
      '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19',
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20',
      '002  REDACTED V     C        03:09:00:13 03:09:55:19 01:00:43:12 01:01:38:18',
      #    '0004 KASS1 A1234V C        00:00:00:00 00:00:16:06  10:00:41:08 10:00:57:14'
    ].freeze

    #  ituld 'handle the event with multiple audio tracks' do
    #    m = EDL::EventMatcher.new(25)
    #
    #    clip = m.apply([],
    #      '0004 KASS1 A1234V C        00:00:00:00 00:00:16:06  10:00:41:08 10:00:57:14'
    #    )
    #    expect(clip).to be_a(EDL::Event)
    #    expect("A1234").to eq clip.track
    #  end

    it 'produce an Event' do
      m = EDL::EventMatcher.new(25)

      clip = m.apply([],
                     '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17')

      expect(clip).to be_a(EDL::Event)

      expect('020').to eq clip.num
      expect('008C').to eq clip.reel
      expect('V').to eq clip.track

      expect('08:04:24:24'.tc).to eq clip.src_start_tc

      expect('08:04:25:19'.tc).to eq clip.src_end_tc
      expect('01:00:25:22'.tc).to eq clip.rec_start_tc
      expect('01:00:26:17'.tc).to eq clip.rec_end_tc

      expect(clip.transition).to be_nil
      expect(clip.timewarp).to be_nil
      expect(clip.outgoing_transition_duration).to be_zero
    end

    it 'produce an Event when reel has dots and output a warning' do
      m = EDL::EventMatcher.new(25)

      # flexmock($stderr).should_receive(:puts).with("Reel name \"TIRED_EDITOR.MOV\" contains dots or spaces, beware.")

      clip = m.apply([],
                     '020  TIREDEDITOR.MOV     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17')

      expect(clip).to be_a(EDL::Event)

      expect('020').to eq clip.num
      expect('TIREDEDITOR.MOV').to eq clip.reel
      expect('V').to eq clip.track

      expect('08:04:24:24'.tc).to eq clip.src_start_tc
    end
    
    it 'produce an Event when reel has asterisks' do
      m = EDL::EventMatcher.new(25)
      
      clip = m.apply([],
                    '047  *TIRED*EDITOR* V     C        00:00:38:15 00:00:39:08 01:06:37:03 01:06:37:20 ')
      
      expect(clip).to be_a(EDL::Event)
      
      expect('047').to eq clip.num
      expect('*TIRED*EDITOR*').to eq clip.reel
      expect('V').to eq clip.track
      
      expect('00:00:38:15'.tc).to eq clip.src_start_tc
    end

    it 'produce an Event with dissolve' do
      m = EDL::EventMatcher.new(25)

      dissolve = m.apply([],
                         '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20')
      expect(dissolve).to be_a(EDL::Event)

      expect('025').to eq dissolve.num
      expect('GEN').to eq dissolve.reel
      expect('V').to eq dissolve.track
      expect(dissolve.has_transition?).to be_truthy

      tr = dissolve.transition

      expect(tr).to be_a(EDL::Dissolve)
      expect(25).to eq tr.duration
    end

    it 'produce a vanilla Event with proper source length' do
      # This one has EXACTLY 4 frames of source
      m = EDL::EventMatcher.new(25)
      clip = m.apply([], '001  GEN      V     C        00:01:00:00 00:01:00:04 01:00:00:00 01:00:00:04')
      expect(clip).to be_a(EDL::Event)
      expect(4).to eq clip.src_length
    end

    it 'set flag on the previous event in the stack when a dissolve is encountered' do
      m = EDL::EventMatcher.new(25)
      previous_evt = double
      expect(previous_evt).to receive(:outgoing_transition_duration=).with(25)

      m.apply([previous_evt],
              '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20')
    end

    it 'generate a Wipe' do
      m = EDL::EventMatcher.new(25)
      wipe = m.apply([],
                     '025  GEN      V     W001  025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20')

      tr = wipe.transition
      expect(tr).to be_a(EDL::Wipe)
      expect(25).to eq tr.duration
      expect('001').to eq tr.smpte_wipe_index
    end

    EVT_PATTERNS.each do |pat|
      it "match #{pat.inspect}" do
        expect(EDL::EventMatcher.new(25).matches?(pat)).to be_truthy
      end
    end

    it 'pass the framerate that it received upon instantiation to the Timecodes being created' do
      m = EDL::EventMatcher.new(30)
      clip = m.apply([],
                     '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17')
      expect(30).to eq clip.rec_start_tc.fps
      expect(30).to eq clip.rec_end_tc.fps
      expect(30).to eq clip.src_start_tc.fps
      expect(30).to eq clip.src_end_tc.fps
    end
  end

  describe 'CommentMatcher' do
    it 'match a comment' do
      line = '* COMMENT: PURE GARBAGE'
      expect(EDL::CommentMatcher.new.matches?(line)).to be_truthy
    end
    
    it 'match a comment that that contains an asterisk' do
      line = '* COMMENT: PURE *GARBAGE*'
      expect(EDL::CommentMatcher.new.matches?(line)).to be_truthy
    end

    it 'apply the comment to the last clip on the stack' do
      line = '* COMMENT: PURE GARBAGE'

      comments = []
      mok_evt = double

      expect(mok_evt).to receive(:comments).exactly(3).times.and_return(comments)
      2.times { EDL::CommentMatcher.new.apply([mok_evt], line) }

      expect(['* COMMENT: PURE GARBAGE', '* COMMENT: PURE GARBAGE']).to eq mok_evt.comments
    end
  end

  describe 'FallbackMatcher' do
    it 'match anything' do
      line = 'SOME'
      expect(EDL::FallbackMatcher.new.matches?(line)).to be_truthy

      line = 'OR ANOTHER  '
      expect(EDL::FallbackMatcher.new.matches?(line)).to be_truthy
    end

    it 'not match whitespace' do
      line = "\s\s\s\r\n\r"
      expect(EDL::FallbackMatcher.new.matches?(line)).to be_falsey
    end

    it 'append the matched content to comments' do
      e = double
      cmts = []
      expect(e).to receive(:comments).twice.and_return(cmts)

      EDL::FallbackMatcher.new.apply([e], 'FOOBAR')
      expect(['FOOBAR']).to eq cmts

      EDL::FallbackMatcher.new.apply([e], 'FINAL CUT PRO REEL: 006-I REPLACED BY: 006I')
      expect(['FOOBAR', 'FINAL CUT PRO REEL: 006-I REPLACED BY: 006I']).to eq cmts
    end

    it 'raise an ApplyError if no clip is on the stack' do
      expect do
        EDL::FallbackMatcher.new.apply([], 'FINAL CUT PRO REEL: 006-I REPLACED BY: 006I')
      end.to raise_error(EDL::Matcher::ApplyError)
    end
  end

  describe 'ClipNameMatcher' do
    it 'match a clip name' do
      line = '* FROM CLIP NAME:  TAPE_6-10.MOV'
      expect(EDL::NameMatcher.new.matches?(line)).to be_truthy
    end

    it 'match a clip name without space after star' do
      line = '*FROM CLIP NAME:  TAPE_6-10.MOV'
      expect(EDL::NameMatcher.new.matches?(line)).to be_truthy
    end
    
    it 'match a clip name containing an asterisk' do
      line = '* FROM CLIP NAME:  18B_1*'
      expect(EDL::NameMatcher.new.matches?(line)).to be_truthy
    end

    it 'not match a simple comment' do
      line = '* JUNK'
      expect(EDL::NameMatcher.new.matches?(line)).to be_falsey
    end

    it 'apply the name to the last event on the stack' do
      line = '* FROM CLIP NAME:  TAPE_6-10.MOV'

      mok_evt = double
      comments = []
      expect(mok_evt).to receive(:clip_name=).with('TAPE_6-10.MOV')
      expect(mok_evt).to receive(:comments).and_return(comments)

      EDL::NameMatcher.new.apply([mok_evt], line)
      expect(['* FROM CLIP NAME:  TAPE_6-10.MOV']).to eq comments
    end
  end

  describe 'EffectMatcher' do
    it 'not match a simple comment' do
      line = '* STUFF'
      expect(EDL::EffectMatcher.new.matches?(line)).to be_falsey
    end

    it 'match a dissolve name' do
      line = '* EFFECT NAME: CROSS DISSOLVE'
      expect(EDL::EffectMatcher.new.matches?(line)).to be_truthy
    end

    it 'match a dissolve name without space after the asterisk' do
      line = '*EFFECT NAME: CROSS DISSOLVE'
      expect(EDL::EffectMatcher.new.matches?(line)).to be_truthy
    end
    
    it 'match a dissolve name containing an asterisk' do
      line = '* EFFECT NAME: *CROSS DISSOLVE'
      expect(EDL::EffectMatcher.new.matches?(line)).to be_truthy
    end

    it 'apply the effect name to the transition of the last event on the stack' do
      line = '* EFFECT NAME: CROSS DISSOLVE'
      mok_evt = double
      mok_transition = double
      cmt = []

      expect(mok_evt).to receive(:transition).and_return(mok_transition)
      expect(mok_evt).to receive(:comments).and_return(cmt)

      expect(mok_transition).to receive(:effect=).with('CROSS DISSOLVE')

      EDL::EffectMatcher.new.apply([mok_evt], line)

      expect(['* EFFECT NAME: CROSS DISSOLVE']).to eq cmt
    end
  end

  describe 'An EDL with mixed line breaks' do
    it 'parse without errors' do
      list = EDL::Parser.new.parse(File.open(MIXED_LINEBREAKS))
      expect(['* A', '* B', '* C', '* D', '* E', '* F', '* G']).to eq list[0].comments
    end
  end

  describe 'A complex EDL passed via Parser' do
    it 'parse without errors' do
      expect { EDL::Parser.new.parse(File.open(FORTY_FIVER)) }.to_not raise_error
    end

    it 'parse the EDL with \\r line breaks properly' do
      evts = EDL::Parser.new.parse(File.read(PLATES))
      expect(3).to eq evts.length
    end

    # TODO: this does not belong here
    it 'be properly rewritten from zero' do
      complex = EDL::Parser.new.parse(File.open(FORTY_FIVER))
      from_zero = complex.from_zero

      expect(complex.length).to eq(from_zero.length), 'Should have the same number of events'

      expect(from_zero[0].rec_start_tc).to be_zero
      expect('00:00:42:16'.tc).to eq from_zero[-1].rec_end_tc
    end
  end

  describe 'A FinalCutPro speedup with fade at the end' do
    it 'be parsed cleanly' do
      list = EDL::Parser.new.parse(File.open(SPEEDUP_AND_FADEOUT))

      expect(2).to eq list.length

      first_evt = list[0]

      tw = first_evt.timewarp
      expect(tw).to be_a(EDL::Timewarp)

      expect(689).to eq first_evt.rec_length
      expect(714).to eq first_evt.rec_length_with_transition

      expect(1000).to eq tw.actual_length_of_source
      expect(140).to eq tw.speed

      expect(1000).to eq first_evt.src_length

      expect('01:00:00:00').to eq first_evt.capture_from_tc.to_s
      expect('01:00:40:00').to eq first_evt.capture_to_tc.to_s
    end
  end

  describe 'In the trailer EDL the event 4' do
    it 'not have too many comments' do
      evts = EDL::Parser.new.parse(File.open(TRAILER_EDL))
      evt = evts[6]
      expect(5).to eq evt.comments.length
    end
  end

  describe 'A FinalCutPro speedup and reverse with fade at the end' do
    it 'parse cleanly' do
      first_evt = EDL::Parser.new.parse(File.open(SPEEDUP_REVERSE_AND_FADEOUT)).shift

      expect(first_evt).to be_reverse

      expect(689).to eq first_evt.rec_length
      expect(714).to eq first_evt.rec_length_with_transition

      tw = first_evt.timewarp

      expect('1h 1f'.tc).to eq tw.source_used_from
      expect('1h 40s'.tc).to eq tw.source_used_upto
    end
  end
end
