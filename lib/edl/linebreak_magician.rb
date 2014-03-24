# EDLs sometimes come with \r line breaks, and this is something that fails
# with Ruby standard line separator detection. We need something to help us
# with that. In this case we can just do a bulk replace because EDLs will be relatively
# small for even very long features.
class EDL::LinebreakMagician < StringIO
  LOOSE_CR = /#{Regexp.escape("\r")}/
  def initialize(with_io)
    blob = with_io.read
    super(blob.gsub(LOOSE_CR, "\n"))
  end
end