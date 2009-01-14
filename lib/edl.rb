require "rubygems"
require "timecode"
require 'stringio'

# A simplistic EDL parser. Current limitations: no support for DF timecode, no support for audio,
# no support for split edits, no support for key effects, no support for audio
module EDL
  VERSION = "0.0.2"
  DEFAULT_FPS = 25
  
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
        if e.ends_with_a_transition?
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
      x = self.class.new(renumed)
      puts x.inspect
      x
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
  
  # Represents an edit event
  class Event
    # Event number as in the EDL
    attr_accessor :num

    # Reel name as in the EDL
    attr_accessor :reel
    
    # Event tracks as in the EDL
    attr_accessor :track

    # Source start timecode of the start frame as in the EDL,
    # no timewarps or dissolves included
    attr_accessor :src_start_tc

    # Source end timecode of the last frame as in the EDL,
    # no timewarps or dissolves included
    attr_accessor :src_end_tc

    # Record start timecode of the event in the master as in the EDL
    attr_accessor :rec_start_tc 

    # Record end timecode of the event in the master as in the EDL,
    # outgoing transition is not included
    attr_accessor :rec_end_tc

    # Array of comment lines verbatim (all comments are included)
    attr_accessor :comments

    # Clip name contained in FROM CLIP NAME: comment
    attr_accessor :clip_name

    # Timewarp metadata (an EDL::Timewarp), or nil if no retime is made
    attr_accessor :timewarp

    # Incoming transition metadata (EDL::Transition), or nil if no transition is used
    attr_accessor :transition
    
    # Whether the event ends with an outgoing transition. 
    # Also available as ends_with_a_transition?
    attr_accessor :ends_with_a_transition

    # How long is the incoming transition on the next event
    attr_accessor :outgoing_transition_duration
    
    # Output a textual description (will not work as an EDL line!)
    def to_s
      %w( num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc).map{|a| self.send(a).to_s}.join("  ")
    end
    
    def inspect
      to_s
    end
    
    
    def comments #:nodoc:
      @comments ||= []
      @comments
    end
    
    # Is the clip reversed in the edit?
    def reverse?
      (timewarp && timewarp.reverse?)
    end
    alias_method :reversed?, :reverse?
    
    def copy_properties_to(evt)
      %w( num reel track src_start_tc src_end_tc rec_start_tc rec_end_tc).each do | k |
        evt.send("#{k}=", send(k)) if evt.respond_to?(k)
      end
      evt
    end
    
    # Returns true if the clip starts with a transiton (not a jump cut)
    def has_transition?
      !transition.nil?
    end
    
    # Returns true if the clip ends with a transition (if the next clip starts with a transition)
    def ends_with_a_transition?
      !!ends_with_a_transition
    end
    
    # Returns true if the clip has a timewarp (speed ramp, motion memory, you name it)
    def has_timewarp?
      !timewarp.nil?
    end
    
    # Is this a black slug?
    def black?
      reel == 'BL'
    end
    alias_method :slug?, :black?
    
    # Get the record length of the event (how long it occupies in the EDL without an eventual outgoing transition)
    def rec_length
      (rec_end_tc - rec_start_tc).to_i
    end
    
    # How long does the capture need to be to complete this event including timewarps and transitions
    def src_length
      vanilla_length = rec_length
      # Expand transition
      vanilla_length += @outgoing_transition_duration if ends_with_a_transition?
      # Expand timewarp
      if timewarp
        (vanilla_length / 100.0 * (timewarp.speed_in_percent).abs).ceil
      else
        vanilla_length
      end
    end
    
    alias_method :capture_length, :src_length

    # Capture from (and including!) this timecode to complete this event including timewarps and transitions
    def capture_from_tc
      src_start_tc
    end
    
    # Capture up to (but not including!) this timecode to complete this event including timewarps and transitions
    def capture_to_tc
      src_start_tc + src_length
    end
    
    # Returns true if this event is a generator
    def generator?
      black? || (%(AX GEN).include?(reel))
    end
  end
    
  # Represents a transition. We currently only support dissolves and SMPTE wipes
  # Will be avilable as EDL::Clip#transition
  class Transition
    
    # Length of the transition in frames
    attr_accessor :duration
    
    attr_accessor :effect
  end
  
  # Represents a dissolve
  class Dissolve < Transition
  end
  
  # Represents an SMPTE wipe
  class Wipe < Transition
    attr_accessor :smpte_wipe_index
  end
  
  # Represents a timewarp. Will be placed in EDL::Event#timewarp
  class Timewarp
    
    # What is the actual framerate of the clip (float)
    attr_accessor :actual_framerate

    attr_accessor :clip #:nodoc:
    
    # Get the speed in percent (reverse will report -100)
    def speed_in_percent
      (actual_framerate.to_f / clip.src_start_tc.fps) * 100
    end
    
    # Get the actual end of source that is needed for the timewarp to be computed properly,
    # round up to not generate stills at ends of clips
    def actual_src_end_tc
      unless reverse?
        clip.src_start_tc + actual_length_of_source
      else
        clip.src_start_tc
      end
    end
    
    def actual_src_start_tc
      unless reverse?
        clip.src_start_tc
      else
        clip.src_start_tc - actual_length_of_source
      end
    end
    
    # Returns the true number of frames that is needed to complete the timewarp edit
    def actual_length_of_source
      length_in_edit = (clip.src_end_tc - clip.src_start_tc).to_i
      ((length_in_edit / 25.0) * actual_framerate).ceil.abs
    end
    
    # Is the clip reversed?
    def reverse?
      actual_framerate < 0
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
      line =~ @regexp
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
      stack[-1].comments << line.scan(@regexp).flatten.pop.strip
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
        when 'D'
          d = Dissolve.new
          d.duration = props.delete(:duration).to_i
          d
        when /W/
          w = Wipe.new
          w.duration = props.delete(:duration)
          w.smpte_wipe_index = transition_idx.gsub(/W/, '')
          w
        else
          nil
      end
      
      # Give a hint on the incoming clip as well
      if evt.transition && stack[-1]
        stack[-1].ends_with_a_transition, stack[-1].outgoing_transition_duration = true, evt.transition.duration
      end
      
      props.each_pair { | k, v | evt.send("#{k}=", v) }
      
      stack << evt
      evt # FIXME - we dont need to return this is only used by tests
    end
  end
  
  #:startdoc:
  
  # Is used to parse an EDL
  class Parser
    
    attr_reader :fps
    
    # Initialize an EDL parser. Pass the FPS to it, as the usual EDL does not contain any kind of reference 
    # to it's framerate
    def initialize(with_fps = DEFAULT_FPS)
      @fps = with_fps
    end
    
    def get_matchers #:nodoc:
      [ EventMatcher.new(@fps), EffectMatcher.new, NameMatcher.new, TimewarpMatcher.new(@fps), CommentMatcher.new ]
    end
    
    # Parse a passed File or IO object line by line
    def parse(io)
      return parse(StringIO.new(io.to_s)) unless io.respond_to?(:eof?)
      
      stack, matchers = List.new, get_matchers
      until io.eof?
        current_line = io.gets.strip
        matchers.each do | matcher |
          next unless matcher.matches?(current_line)
          
          begin
            matcher.apply(stack, current_line)
          rescue Matcher::ApplyError => e
            STDERR.puts "Cannot parse #{current_line} - #{e}"
          end
        end
      end
      stack
    end
    
    # Parse a passed string as an EDL
    def parse_string(str)
      parse(StringIO.new(str))
    end
    
    # Init a Timecode object from the passed elements with the passed framerate
    def self.timecode_from_line_elements(elements, fps)
      args = (0..3).map{|_| elements.shift.to_i} + [fps.to_f]
      Timecode.at(*args)
    end
  end

end