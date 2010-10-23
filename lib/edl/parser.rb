module EDL
  
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
  
    # Parse a passed File or IO object line by line, or the whole string
    def parse(input_string_or_io)
      return parse(StringIO.new(input_string_or_io)) unless input_string_or_io.respond_to?(:read)
      
      magic = ::EDL::LinebreakMagician.new(input_string_or_io)
      
      # Normalize line breaks
      stack, matchers = List.new, get_matchers
      
      while current_line = magic.gets
        
        m = matchers.find{|m| m.matches?(current_line) }
        
        next unless m
        begin
          m.apply(stack, current_line)
          stack[-1].line_number = magic.lineno if m.is_a?(EventMatcher)
        rescue Matcher::ApplyError => e
          STDERR.puts "Cannot parse #{current_line} - #{e}"
        end
      end
      stack
    end
  
    # Init a Timecode object from the passed elements with the passed framerate
    def self.timecode_from_line_elements(elements, fps) #:nodoc:
      args = (0..3).map{|_| elements.shift.to_i} + [fps.to_f]
      Timecode.at(*args)
    end
  end
end