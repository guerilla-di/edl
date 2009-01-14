module EDL
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
end