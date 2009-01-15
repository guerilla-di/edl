module EDL
  # Represents a timewarp. Will be placed in EDL::Event#timewarp
  # For a reversed clip, the source start we get from the EDL in the src start
  # is the LAST used frame. For a pos rate clip, the source start is the bona fide source start. Nice eh? 
  class Timewarp
  
    # What is the actual framerate of the clip (float)
    attr_accessor :actual_framerate
    attr_accessor :clip #:nodoc:
    
    # Does this timewarp reverse the clip?
    def reverse?
      @actual_framerate < 0
    end
    
    # Get the speed in percent
    def speed_in_percent
      (@actual_framerate / @clip.rec_start_tc.fps) * 100
    end
    alias_method :speed, :speed_in_percent
    
    # Compute the length of the clip we need to capture. The length is computed in frames and
    # is always rounded up (better one frame more than one frame less!)
    def actual_length_of_source
      # First, get the length of the clip including a transition. This is what we are scaled to.
      target_len = @clip.rec_length_with_transition.to_f
      # Determine the framerate scaling factor, this is the speed
      factor = @actual_framerate / @clip.rec_start_tc.fps
      (target_len * factor).ceil.abs
    end
    
    # What is the starting frame for the captured clip? If we are a reverse, then the src start of the
    # clip is our LAST frame, otherwise it's the first
    def source_used_from
      # TODO: account for the 2 frame deficiency which is suspicious
      compensation = 2
      reverse? ? (@clip.src_start_tc - actual_length_of_source + compensation) : @clip.src_start_tc
    end
    
    # Where to end the capture? This is also dependent on whether we are a reverse or not
    def source_used_upto
      source_used_from + actual_length_of_source
    end
  end
end