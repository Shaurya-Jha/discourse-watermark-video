# frozen_string_literal: true
module DiscourseVideoWatermark
  class FFmpegCommand
    # Returns an Array suitable for Discourse::Utils.execute_command
    def self.build(input_path:, output_path:, text:, image_url:, position:, fontsize:, opacity:)
      overlay = (position.to_s.strip.presence || "10:10")

      wm_path = resolve_watermark_path(image_url)

      if wm_path
        # Optional: scale watermark to ~20% of video width, then overlay
        filter = "[1]scale=iw*0.2:-1[wm];[0][wm]overlay=#{overlay}"
        [
          "ffmpeg", "-y",
          "-i", input_path,         # [0] video
          "-i", wm_path,            # [1] watermark image
          "-filter_complex", filter,
          "-c:v", "libx264", "-preset", "veryfast", "-crf", "22",
          "-c:a", "copy",
          "-movflags", "+faststart",
          output_path
        ]
      else
        # Text watermark fallback
        x, y = overlay.split(":")
        x ||= "10"; y ||= "10"
        draw = "drawtext=text='#{shell_escape_text(text)}':x=#{x}:y=#{y}:fontcolor=white@#{opacity.to_f.clamp(0,1)}:fontsize=#{fontsize.to_i}"
        [
          "ffmpeg", "-y",
          "-i", input_path,
          "-vf", draw,
          "-c:v", "libx264", "-preset", "veryfast", "-crf", "22",
          "-c:a", "copy",
          "-movflags", "+faststart",
          output_path
        ]
      end
    end

    # Return a local filesystem path for the watermark image, or nil if unavailable.
    def self.resolve_watermark_path(image_url)
      return nil if image_url.to_s.strip.empty?

      # Local absolute/relative path?
      if File.exist?(image_url.to_s)
        return image_url.to_s
      end

      # HTTP(S) URL? download to a temp file
      if image_url.to_s =~ %r{\Ahttps?://}i
        return download_temp(image_url.to_s)
      end

      # Not found / unsupported
      nil
    end

    def self.download_temp(url)
      require "open-uri"
      require "uri"
      require "net/http"

      url = URI.parse(url)    # sanitize and parse the URL

      tf = Tempfile.new(["wm-", File.extname(url.path.presence || ".png")])
      tf.binmode
      tf.write(url.open(url, "rb") { |io| io.read })
      tf.flush
      tf.path  # caller does not unlink; ok for short-lived dev jobs
    rescue => e
      Rails.logger.error("[VideoWatermark] watermark download failed: #{e.class}: #{e.message}")
      nil
    end

    def self.shell_escape_text(text)
      (text || "").gsub("\\", "\\\\\\").gsub("'", "\\\\'").gsub(":", "\\\\:")
    end
  end
end