require "rubygems"
require "timecode"
require "stringio"

require File.dirname(__FILE__) + '/edl/event'
require File.dirname(__FILE__) + '/edl/transition'
require File.dirname(__FILE__) + '/edl/timewarp'
require File.dirname(__FILE__) + '/edl/parser'
require File.dirname(__FILE__) + '/edl/linebreak_magician'

# A simplistic EDL parser
module EDL
  VERSION = "0.1.3"
  DEFAULT_FPS = 25.0
  
  # Represents an EDL, is returned from the parser. Traditional operation is functional style, i.e.
  #  edl.renumbered.without_transitions.without_generators
  class List < Array
    
    def events #:nodoc:
      STDERR.puts "EDL::List#events is deprecated and will be removed, use EDL::List as an array instead"
      self
    end
    
    # Return the same EDL with all dissolves stripped and replaced by the clips underneath
    def without_transitions
      # Find dissolves
      cpy = []
      each_with_index do | e, i |
        # A dissolve always FOLLOWS the incoming clip
        if e.ends_with_transition?
          dissolve = self[i+1]
          len = dissolve.transition.duration.to_i
          
          # The dissolve contains the OUTGOING clip, we are the INCOMING. Extend the
          # incoming clip by the length of the dissolve, that's the whole mission actually
          incoming = e.copy_properties_to(e.class.new)
          incoming.src_end_tc += len
          incoming.rec_end_tc += len
          
          outgoing = dissolve.copy_properties_to(Event.new)
          
          # Add the A suffix to the ex-dissolve
          outgoing.num += 'A'
          
          # Take care to join the two if they overlap - TODO
          cpy << incoming
          cpy << outgoing
        elsif e.has_transition?
          # Skip, already handled on the previous clip
        else
          cpy << e.dup
        end
      end
      # Do not renumber events
      # (0...cpy.length).map{|e| cpy[e].num = "%03d" % e }
      self.class.new(cpy)
    end
    
    # Return the same EDL, with events renumbered starting from 001
    def renumbered
      renumed = self.dup
      pad = renumed.length.to_s.length
      pad = 3 if pad < 3
      
      (0...renumed.length).map{|e| renumed[e].num = "%0#{pad}d" % (e+1) }
      self.class.new(renumed)
    end
        
    # Return the same EDL with all timewarps expanded to native length. Clip length
    # changes have rippling effect on footage that comes after the timewarped clip
    # (so this is best used in concert with the original EDL where record TC is pristine)
    def without_timewarps
      self.class.new(
        map do | e |
          if e.has_timewarp?
            repl = e.copy_properties_to(e.class.new)
            from, to = e.timewarp.actual_src_start_tc, e.timewarp.actual_src_end_tc
            repl.src_start_tc, repl.src_end_tc, repl.timewarp = from, to, nil
            repl
          else
            e
          end
        end
      )
    end
    
    # Return the same EDL without AX, BL and other GEN events (like slug, text and solids).
    # Usually used in concert with "without_transitions"
    def without_generators
      self.class.new(self.reject{|e| e.generator? })
    end
    
    # Return the list of clips used by this EDL at full capture length
    def capture_list
      without_generators.without_timewarps.spliced.from_zero
    end
    
    # Return the same EDL with the first event starting at 00:00:00:00 and all subsequent events
    # shifted accordingly
    def from_zero
      shift_by = self[0].rec_start_tc
      self.class.new(
        map do | original |
          e = original.dup
          e.rec_start_tc =  (e.rec_start_tc - shift_by)
          e.rec_end_tc =  (e.rec_end_tc - shift_by)
          e
        end
      )
    end
    
    # Return the same EDL with neighbouring clips joined at cuts where applicable (if a clip
    # is divided in two pieces it will be spliced). Most useful in combination with without_timewarps
    def spliced
      spliced_edl = inject([]) do | spliced, cur  |
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
  
  #:stopdoc:
  
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
    
    def matches?(line)
      !!(line =~ @regexp)
    end
    
    def apply(stack, line)
      STDERR.puts "Skipping #{line}"
    end
  end
  
  # EDL clip comment matcher, a generic one
  class CommentMatcher < Matcher
    def initialize
      super(/\* (.+)/)
    end
    
    def apply(stack, line)
      stack[-1].comments.push("* %s" % line.scan(@regexp).flatten.pop.strip)
    end
  end
  
  # Fallback matcher for things like FINAL CUT PRO REEL
  class FallbackMatcher < Matcher
    def initialize
      super(/^(\w)(.+)/)
    end
    
    def apply(stack, line)
      begin
        stack[-1].comments << line.scan(@regexp).flatten.join.strip
      rescue NoMethodError 
        raise ApplyError.new("Line can only be a comment but no event was on the stack", line)
      end
    end
  end

  # Clip name matcher
  class NameMatcher < Matcher
    def initialize
      super(/\* FROM CLIP NAME:(\s+)(.+)/)
    end
    
    def apply(stack, line)
      stack[-1].clip_name = line.scan(@regexp).flatten.pop.strip
      CommentMatcher.new.apply(stack, line)
    end
  end
  
  class EffectMatcher < Matcher
    def initialize
      super(/\* EFFECT NAME:(\s+)(.+)/)
    end
    
    def apply(stack, line)
      stack[-1].transition.effect = line.scan(@regexp).flatten.pop.strip
      CommentMatcher.new.apply(stack, line)
    end
  end
  
  class TimewarpMatcher < Matcher
    
    attr_reader :fps
    
    def initialize(fps)
      @fps = fps
      @regexp = /M2(\s+)(\w+)(\s+)(\-?\d+\.\d+)(\s+)(\d{1,2}):(\d{1,2}):(\d{1,2}):(\d{1,2})/
    end
    
    def apply(stack, line)
      matches = line.scan(@regexp).flatten.map{|e| e.strip}.reject{|e| e.nil? || e.empty?}
      
      from_reel = matches.shift
      fps = matches.shift
      
      begin
        # FIXME
        tw_start_source_tc = Parser.timecode_from_line_elements(matches, @fps)
      rescue Timecode::Error => e
        raise ApplyError, "Invalid TC in timewarp (#{e})", line
      end
      
      evt_with_tw = stack.reverse.find{|e| e.src_start_tc == tw_start_source_tc && e.reel == from_reel }
      
      unless evt_with_tw
        raise ApplyError, "Cannot find event marked by timewarp", line
      else
        tw = Timewarp.new
        tw.actual_framerate, tw.clip = fps.to_f, evt_with_tw
        evt_with_tw.timewarp = tw
      end
    end
  end
  
  # Drop frame goodbye
  TC = /(\d{1,2}):(\d{1,2}):(\d{1,2}):(\d{1,2})/
  
  class EventMatcher < Matcher

    # 021  009      V     C        00:39:04:21 00:39:05:09 01:00:26:17 01:00:27:05
    EVENT_PAT = /(\d+)(\s+)(\w+)(\s+)(\w+)(\s+)(\w+)(\s+)((\w+\s+)?)#{TC} #{TC} #{TC} #{TC}/
    
    attr_reader :fps
    
    def initialize(some_fps)
      super(EVENT_PAT)
      @fps = some_fps
    end
    
    def apply(stack, line)
      
      matches = line.scan(@regexp).shift
      props = {}
      
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
          props[k] = EDL::Parser.timecode_from_line_elements(matches, @fps)
        rescue Timecode::Error => e 
          raise ApplyError, "Cannot parse timecode - #{e}", line
        end
      end
      
      evt = Event.new
      transition_idx = props.delete(:transition)
      evt.transition = case transition_idx
        when 'C'
          nil
        when 'D'
          d = Dissolve.new
          d.duration = props.delete(:duration).to_i
          d
        when /W(\d+)/
          w = Wipe.new
          w.duration = props.delete(:duration).to_i
          w.smpte_wipe_index = transition_idx.gsub(/W/, '')
          w
        when 'K'
          k = Key.new
          k.duration = props.delete(:duration).to_i
          k
        else
          raise "Unknown transition type #{transition_idx}"
      end
      
      # Give a hint on the incoming clip as well
      if evt.transition && stack[-1]
        stack[-1].outgoing_transition_duration = evt.transition.duration
      end
      
      props.each_pair { | k, v | evt.send("#{k}=", v) }
      
      stack << evt
      evt # FIXME - we dont need to return this is only used by tests
    end
  end
  
  #:startdoc:

end