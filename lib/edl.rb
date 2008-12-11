require File.dirname(__FILE__) + "/../../timecode/timecode"

# A simplistic EDL parser. Current limitations: no support for DF timecode, no support for audio
module EDL
  
  # Represents an EDL, is returned from the parser. Traditional operation is functional style, i.e.
  #
  #  edl.renumbered.without_dissolves.without_generators.as_edit_of(another_edl)...
  class List
    attr_accessor :events
    def initialize(events = [])
      @events = events.dup
    end
    
    # Return the same EDL with all dissolves stripped and replaced by the clips under them
    def without_dissolves
      # Find dissolves
      cpy = []
      
      @events.each_with_index do | e, i |
        # A dissolve always FOLLOWS the incoming clip
        if @events[i+1] && @events[i+1].has_transition?
          dissolve = @events[i+1]
          len = dissolve.transition.duration.to_i
          
          # The dissolve contains the OUTGOING clip, we are the INCOMING. Extend the
          # incoming clip by the length of the dissolve, that's the whole mission actually
          incoming = e.copy_properties_to(e.class.new)
          incoming.src_end_tc += len
          incoming.rec_end_tc += len
          
          outgoing = dissolve.copy_properties_to(Clip.new)
          
          # Add the A suffix to the ex-dissolve
          outgoing.num += 'A'
          
          # Take care to join the two if they overlap - TODO
          cpy << incoming
          cpy << outgoing
        elsif e.has_transition?
          # Skip, already handled!
        else
          cpy << e.dup
        end
      end
      # Do not renumber events
      # (0...cpy.length).map{|e| cpy[e].num = "%03d" % e }
      self.class.new(cpy)
    end
    
    def renumbered
      renumed = @events.dup
      pad = renumed.length.to_s.length
      pad = 3 if pad < 3
      
      (0...renumed.length).map{|e| renumed[e].num = "%0#{pad}d" % (e+1) }
      x = self.class.new(renumed)
      puts x.inspect
      x
    end
    
    # Return the same EDL with all timewarps expanded to native length. Clip length
    # changes have rippling effect on footage that comes after the timewarped clip
    # (so this is best used in concert with the original EDL where record TC is pristine)
    def without_timewarps
      raise "Implement me"
    end
    
    # Return the same EDL without AX, BL and other GEN events (like slug, text and solids).
    # Usually used in concert with "without_dissolves"
    def without_generators
      gen_reels = %w(AX BL GEN)
      self.class.new(@events.reject{|e| gen_reels.include?(e.reel) })
    end
    
    def spliced
      spliced_edl = @events.inject([]) do | spliced, cur  |
        latest = spliced[-1]
        # Append to latest if splicable
        if latest && (latest.reel == cur.reel) && (cur.src_start_tc == (latest.src_end_tc + 1))
          latest.src_end_tc = cur.src_end_tc
          latest.rec_end_tc = cur.rec_end_tc
        else
          spliced << cur.dup
        end
        spliced
      end
      self.class.new(spliced_edl)
    end
  end
  
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
      %w( num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc).map{|a| self.send(a).to_s}.join("  ")
    end
    
    def inspect
      to_s
    end
    
    def copy_properties_to(evt)
      %w( num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc).each do | k |
        evt.send("#{k}=", send(k)) if evt.respond_to?(k)
      end
      evt
    end
  end
  
  class Clip < Event
    attr_accessor :clip_name, :timewarp_speed
    attr_accessor :transition
    
    # Returns true if the clip starts with a transiton (not a jump cut)
    def has_transition?
      !transition.nil?
    end
    
    def has_timewarp?
      false
    end
    
    def black?
      reel == 'BL'
    end
    
    def generator?
      black? || (%(AX GEN).include?(reel))
    end
  end
  
  # Represents a transition. We currently only support dissolves and SMPTE wipes
  # Will be avilable as EDL::Clip#transition
  class Transition
    attr_accessor :duration, :effect
  end
  
  # Represents a dissolve
  class Dissolve < Transition
  end
  
  class Wipe < Transition
    attr_accessor :smpte_wipe_index # SMPTE wipe idx
  end

  # A generic matcher
  class Matcher
    class ApplyError < RuntimeError
      def initialize(msg, line)
        super("%s - offending line was '%s'" % [msg, line])
      end
    end
    
    def initialize(with_regexp)
      @regexp = with_regexp
    end
    
    def signals_new_event?
      false
    end
    
    def matches?(line)
      line =~ @regexp
    end
    
    def apply(stack, current_event, line)
      STDERR.puts "Skipping #{line}"
    end
  end
  
  class NameMatcher < Matcher
    def initialize
      super(/\* FROM CLIP NAME:(\s+)(.+)/)
    end
    
    def apply(stack, current_event, line)
      current_event.clip_name = line.scan(@regexp).flatten.pop.strip
    end
  end
  
  class EffectMatcher < Matcher
    def initialize
      super(/\* EFFECT NAME:(\s+)(.+)/)
    end
    
    def apply(stack, current_event, line)
      current_event.transition.effect = line.scan(@regexp).flatten.pop.strip
    end
  end
  
  class TimewarpMatcher < Matcher
    def initialize
      @regexp = /M2(\s+)(\w+)(\s+)(\d+\.\d+)(\s+)(\d{1,2}):(\d{1,2}):(\d{1,2}):(\d{1,2})/
    end
    
    def apply(stack, current_event, line)
      all_evts = stack + [current_event]
      matches = line.scan(@regexp).flatten.map{|e| e.strip}.reject{|e| e.nil? || e.empty?}
      
      from_reel = matches.shift
      fps = matches.shift
      
      begin
        tw_start_source_tc = Parser.timecode_from_line_elements(matches)
      rescue Timecode::Error => e
        raise ApplyError, "Invalid TC in timewarp (#{e})", line
      end
      
      evt_with_tw = all_evts.reverse.find{|e| e.src_start_tc == tw_start_source_tc && e.reel == from_reel }

      unless evt_with_tw
        raise ApplyError, "Cannot find event marked by timewarp", line
      else
        evt_with_tw.timewarp_speed = (25.0/100.0) * fps.to_f
      end
      
    end
  end
  
  # Drop frame goodbye
  TC = /(\d{1,2}):(\d{1,2}):(\d{1,2}):(\d{1,2})/
  
  class EventMatcher < Matcher
    def signals_new_event?
      true
    end

    # 021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05
    EVENT_PAT = /(\d+)(\s+)(\w+)(\s+)(\w+)(\s+)(\w+)(\s+)((\w+\s+)?)#{TC} #{TC} #{TC} #{TC}/
    
    def initialize
      super(EVENT_PAT)
    end
    
    def apply(stack, cur_evt, line)
      
      matches = line.scan(@regexp).shift
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
      props[:transition] = matches.shift
      matches.shift
      
      # Then the optional generator group - skip for now
      if props[:transition] != 'C'
        props[:duration] = matches.shift.strip
      else
        matches.shift
      end
      matches.shift
      
      # Then the timecodes
      [:src_start_tc, :src_end_tc, :rec_start_tc, :rec_end_tc].each do | k |
        begin
          props[k] = EDL::Parser.timecode_from_line_elements(matches)
        rescue Timecode::Error => e 
          raise ApplyError, "Cannot parse timecode - #{e}", line
        end
      end
      
      # This desperatly needs refactoring :-( so that there's no Transition anymore
      evt = Clip.new
      transition_idx = props.delete(:transition)
      tran = case transition_idx
        when 'D'
          d = Dissolve.new
          d.duration = props.delete(:duration)
          d
        when /W/
          w = Wipe.new
          w.duration = props.delete(:duration)
          w.smpte_wipe_index = transition_idx.gsub(/W/, '')
          w
        else
          nil
      end
      evt.transition = tran
      
      props.each_pair { | k, v | evt.send("#{k}=", v) }
      evt
    end
  end
  
  class Parser
    MATCHERS = [
      EventMatcher.new,
      EffectMatcher.new,
      NameMatcher.new,
      TimewarpMatcher.new,
    ]
    
    def parse(io)
      @stack, cur_evt = [], nil
      until io.eof?
        current_line = io.gets.strip
        MATCHERS.each do | matcher |
          next unless matcher.matches?(current_line)
          if matcher.signals_new_event?
            @stack.push(cur_evt) if cur_evt # Start afresh
            cur_evt = matcher.apply(@stack, cur_evt, current_line)
          else
            begin
              matcher.apply(@stack, cur_evt, current_line)
            rescue Matcher::ApplyError => e
              STDERR.puts "Cannot parse #{current_line} - #{e}"
            end
          end
        end
      end
      
      # The last remaining event
      @stack.push(cur_evt) if cur_evt
      return List.new(@stack)
    end
    
    def self.timecode_from_line_elements(elements)
      args = (0..3).map{|_| elements.shift.to_i} + [@fps || 25]
      Timecode.at(*args)
    end
  end
  
  
end