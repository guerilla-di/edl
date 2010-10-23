require "delegate"

# EDLs sometimes come with \r line breaks, and this is something that fails
# with Ruby standard line separator detection. We need something to help us
# with that
class EDL::LinebreakMagician < DelegateClass(IO)
  
  def initialize(with_file)
    sample = with_file.read(2048)
    @linebreak = ["\r\n", "\r", "\n"].find{|separator| sample.include?(separator) }
    with_file.rewind
    __setobj__(with_file)
  end
  
  def each(sep_string = $/, &blk)
    super(@linebreak || sep_string, &blk)
  end
  alias_method :each_line, :each
  
  def gets(sep_string = $/)
    super(@linebreak || sep_string)
  end
  
end