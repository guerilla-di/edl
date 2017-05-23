# frozen_string_literal: true

module EDL
  # When initialized with a file and passed an EDL, will generate thumbnail images
  # of the first frame of every event. It is assumed that the movie file starts at the same
  # frame as the first EDL event.
  class Grabber #:nodoc:
    attr_accessor :ffmpeg_bin, :offset
    def initialize(with_file)
      @source_path = with_file
    end

    def ffmpeg_bin
      @ffmpeg_bin || 'ffmpeg'
    end

    def grab(edl)
      edl.from_zero.events.each do |evt|
        grab_frame_tc = evt.rec_start_tc + (offset || 0)

        to_file = File.dirname(@source_path) + '/' + evt.num + '_' + File.basename(@source_path).gsub(/\.(\w+)$/, '')
        generate_grab(evt.num, grab_frame_tc, to_file)
      end
    end

    def generate_grab(_evt, at, to_file)
      cmd = "#{ffmpeg_bin} -i #{@source_path} -an -ss #{at.with_frames_as_fraction} -vframes 1 -y #{to_file}%d.jpg"
      `#{cmd}`
    end
  end
end
