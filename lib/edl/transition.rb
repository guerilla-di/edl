module EDL
  # Represents a transition. We currently only support dissolves and SMPTE wipes
  # Will be avilable as EDL::Clip#transition
  class Transition
  
    # Length of the transition in frames
    attr_accessor :duration
    
    # Which effect is used (like CROSS DISSOLVE)
    attr_accessor :effect
  end

  # Represents a dissolve
  class Dissolve < Transition
  end

  # Represents an SMPTE wipe
  class Wipe < Transition
    
    # Which SMPTE wipe is needed
    attr_accessor :smpte_wipe_index
  end
  
  class Key < Transition
  end
end