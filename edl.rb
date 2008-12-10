require File.dirname(__FILE__) + "/../timecode/timecode"

module EDL
  
  class Event
    attr_accessor :num, 
      :reel, 
      :track,
      :src_start_tc, 
      :src_end_tc, 
      :rec_start_tc, 
      :rec_end_tc,
      :comments,
      :original_line
    def to_s
      %w( num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc).join("  ")
    end
  end
  
  class Clip < Event
    attr_accessor :clip_name
  end
  
  class VideoClip < Clip; end
  class AudioClip < Clip; end
  
  class Transition < Event
    attr_accessor :effect, :duration
  end
  
  class Black < Clip; end
  class Generator < Event; end
  
  COMMENT_MATCHERS = {
    /FROM CLIP NAME:(\w+)/ => lambda { | evt, match | evt.clip_name = match.flatten.pop.strip },
    /EFFECT NAME:(\.+)/ => lambda { | evt, match | evt.effect = match.flatten.pop.strip }
  }
  
  class Parser
    TC = /(\d{1,2}):(\d{1,2}):(\d{1,2}):(\d{1,2})/

    # 021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05
    EVENT_PAT = /(\d+)(\s+)(\w+)(\s+)(\w+)(\s+)(\w+)(\s+)((\w+\s+)?)#{TC} #{TC} #{TC} #{TC}/
    COMMENT_PAT = /^\* /
    
    def event_line?(line)
      !!(line.strip =~ EVENT_PAT)
    end

    def comment_line?(line)
      !!(line.strip =~ COMMENT_PAT)
    end
    
    def parse(io)
      until io.eof?
        current_line = io.gets
        
        if event_line?(current_line)
          push_event if @event
          @event = event_from_line(current_line)
        elsif comment_line?(current_line)
          COMMENT_MATCHERS.each_pair do | pattern, transformer |
            scan_result = current_line.scan(pattern)
            transformer.call(@event, scan_result) if scan_result
          end
        end
      end
    end
    
    def push_event
      @events ||= []
      @events << @event
    end
    
    def event_from_line(line)
      line.strip!
      
      matches = line.scan(EVENT_PAT).shift
      props = {:original_line => line}
      
      # FIrst one is the event number
      props[:num] = matches.shift
      matches.shift

      # Then the reel
      props[:reel] = matches.shift
      matches.shift

      # Then the track
      props[:track] = matches.shift
      matches.shift

      # Then the type
      props[:type] = matches.shift
      matches.shift
      
      # Then the optional generator group - skip for now
      if props[:type] == 'D'
        props[:duration] = matches.shift.strip
      else
        matches.shift
      end
      matches.shift
      
      # Then the timecodes
      props[:src_start_tc] = timecode_from_line_elements(matches)
      props[:src_end_tc] = timecode_from_line_elements(matches)
      props[:rec_start_tc] = timecode_from_line_elements(matches)
      props[:rec_end_tc] = timecode_from_line_elements(matches)
      
      evt = case props.delete(:type)
        when 'C'
          props[:track] == 'V' ? VideoClip.new : AudioClip.new
        when 'D'
          Transition.new
        else
          Event.new
      end
      puts props.inspect
      props.each_pair { | k, v | evt.send("#{k}=", v) }
      evt
    end
    
    def timecode_from_line_elements(elements)
      args = (0..3).map{|_| elements.shift.to_i} + [@fps || 25]
      Timecode.at(*args)
    end
  end
  
  
end