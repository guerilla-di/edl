describe EDL::Parser do
  describe '#parse' do
    it 'reports error when frame exceeds fps' do
      Timecode.add_custom_framerate!(12.0)
      parser = EDL::Parser.new(12)
      parser.parse(File.read('spec/fixtures/files/45S_SAMPLE.EDL'))
      expect(parser.errors.first).to match(
        /There can be no more than 12\.0 frames \@12\.0, got 13/
      )
    end
  end
end
