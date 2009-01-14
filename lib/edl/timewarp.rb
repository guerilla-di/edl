module EDL
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
end