require File.dirname(__FILE__) + '/../edl'
require 'rubygems'
require 'test/unit'
require 'flexmock'
require 'flexmock/test_unit'


class TestEvent < Test::Unit::TestCase
  def test_attributes_defined
    evt = EDL::Event.new
    %w(  num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc ).each do | em |
      assert_respond_to evt, em
    end
  end
end

class TestParser < Test::Unit::TestCase
  def test_inst
    assert_nothing_raised { EDL::Parser.new }
  end
  
  TRAILER_EDL = File.read(File.dirname(__FILE__) + '/samples/TRAILER_EDL.edl')
  
  EVT_PATTERNS = [
    '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17', 
    '021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05', 
    '022  008C     V     C        08:08:01:23 08:08:02:18 01:00:27:05 01:00:28:00', 
    '023  008C     V     C        08:07:30:02 08:07:30:21 01:00:28:00 01:00:28:19', 
    '024        AX V     C        00:00:00:00 00:00:01:00 01:00:28:19 01:00:29:19', 
    '025        BL V     C        00:00:00:00 00:00:00:00 01:00:29:19 01:00:29:19', 
    '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20',
  ]
  
  CMT_PATTERNS = [
    "* FROM CLIP NAME:  SLUG",
    "* FROM CLIP IS A STILL",
    "* PROBLEM WITH EDIT: CLIP HAD NO TIMECODE TRACK"
  ]
  
  def test_main_patterns
    p = EDL::Parser.new
    EVT_PATTERNS.each do | evt_line |
      assert p.event_line?(evt_line), "#{evt_line} should be recognized as event line"
    end
  end
  
  def test_cmt_patterns
    p = EDL::Parser.new
    CMT_PATTERNS.each do | cmt_line |
      assert p.comment_line?(cmt_line), "#{cmt_line} should be recognized as event line"
    end
  end
  
  def test_timecode_from_elements
    p = EDL::Parser.new
    elems = ["08", "04", "24", "24"]
    assert_nothing_raised { @tc = p.timecode_from_line_elements(elems) }
    assert_kind_of Timecode, @tc
    assert_equal "08:04:24:24", @tc.to_s
    assert elems.empty?, "The elements should have been removed from the array"
  end
  
  def test_clip_generation_from_line
    p = EDL::Parser.new
    
    clip = p.event_from_line(
      '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17'
    )
    
    assert_not_nil clip
    assert_kind_of EDL::Clip, clip
    assert_equal '020', clip.num
    assert_equal '008C', clip.reel
    assert_equal 'V', clip.track
    assert_equal '08:04:24:24', clip.src_start_tc.to_s
    assert_equal '08:04:25:19', clip.src_end_tc.to_s
    assert_equal '01:00:25:22', clip.rec_start_tc.to_s
    assert_equal '01:00:26:17', clip.rec_end_tc.to_s
    assert_equal '020  008C     V     C        08:04:24:24 08:04:25:19 01:00:25:22 01:00:26:17', clip.original_line
  end
  
  
  def test_dissolve_generation_from_line
    p = EDL::Parser.new
    
    dissolve = p.event_from_line(
      '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20'
    )
    assert_not_nil dissolve
    assert_kind_of EDL::Transition, dissolve
    assert_equal '025', dissolve.num
    assert_equal 'GEN', dissolve.reel
    assert_equal 'V', dissolve.track
    assert_equal '025', dissolve.duration
    assert_equal '025  GEN      V     D    025 00:00:55:10 00:00:58:11 01:00:29:19 01:00:32:20', dissolve.original_line
    
  end
end