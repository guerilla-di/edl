module EDL
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
  
    # How long is the incoming transition on the next event
    attr_accessor :outgoing_transition_duration
    
    # Where is this event located in the original file
    attr_accessor :line_number
    
    def initialize(opts = {})
      opts.each_pair{|k,v| send("#{k}=", v) }
      yield(self) if block_given?
    end
    
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
    
    def outgoing_transition_duration #:nodoc:
      @outgoing_transition_duration ||= 0
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
      !!@transition
    end
    alias_method :starts_with_transition?, :has_transition?
    
    # The duration of the incoming transition, or 0 if no transition is used
    def incoming_transition_duration
      @transition ? @transition.duration : 0
    end
    
    # Returns true if the clip ends with a transition (if the next clip starts with a transition)
    def ends_with_transition?
      outgoing_transition_duration > 0
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
      (rec_end_tc.to_i - rec_start_tc.to_i).to_i
    end

    # Get the record length of the event (how long it occupies in the EDL with an eventual outgoing transition)
    def rec_length_with_transition
      rec_length + outgoing_transition_duration.to_i
    end
  
    # How long does the capture need to be to complete this event including timewarps and transitions
    def src_length
      @timewarp ? @timewarp.actual_length_of_source : rec_length_with_transition
    end
  
    alias_method :capture_length, :src_length

    # Capture from (and including!) this timecode to complete this event including timewarps and transitions
    def capture_from_tc
      @timewarp ? @timewarp.source_used_from : src_start_tc
    end
  
    # Capture up to (but not including!) this timecode to complete this event including timewarps and transitions
    def capture_to_tc
      @timewarp ? @timewarp.source_used_upto : (src_end_tc + outgoing_transition_duration)
    end
    
    # Speed of this clip in percent relative to the source speed. 100 for non-timewarped events
    def speed
      @timewarp ? @timewarp.speed : 100
    end
    
    # Returns true if this event is a generator
    def generator?
      black? || (%(AX GEN).include?(reel))
    end
  end
end