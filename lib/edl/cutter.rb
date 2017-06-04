# frozen_string_literal: true

module EDL
  # Can chop an offline edit into events according to the EDL
  class Cutter #:nodoc:
    def initialize(source_path)
      @source_path = source_path
    end

    def cut(edl)
      source_for_cutting = edl.from_zero # .without_transitions.without_generators
      # We need to use the original length in record
      source_for_cutting.events.each do |evt|
        cut_segment(evt, evt.rec_start_tc, evt.rec_start_tc + evt.length)
      end
    end

    def cut_segment(evt, start_at, end_at)
      STDERR.puts "Cutting #{@source_path} from #{start_at} to #{end_at} - #{evt.num}"
    end
  end

  class FFMpegCutter < Cutter #:nodoc:
    def cut_segment(evt, start_at, end_at)
      source_dir = File.dirname(@source_path)
      source_file = File.basename(@source_path)
      dest_segment = File.join(source_dir, ('%s_%s' % [evt.num, source_file]))
      # dest_segment.gsub!(/\.mov$/i, '.mp4')

      offset = end_at - start_at

      cmd = "/opt/local/bin/ffmpeg -i #{@source_path} -ss #{start_at} -vframes #{offset.total} -vcodec photojpeg -acodec copy #{dest_segment}"
      # puts cmd
      `#{cmd}`
    end
  end
end
