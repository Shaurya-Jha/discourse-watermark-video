# frozen_string_literal: true
module ::Jobs
  class WatermarkVideo < ::Jobs::Base
    sidekiq_options queue: "low"

    # Absolute path to plugins/discourse-watermark-video/assets/watermark.png
    WATERMARK_IMAGE_PATH =
      Rails.root.join("plugins", "discourse-watermark-video", "assets", "watermark.jpeg").to_s

    def execute(args)
      upload_id = args[:upload_id]
      raise Discourse::InvalidParameters.new(:upload_id) if upload_id.blank?

      upload = Upload.find_by(id: upload_id)
      return log_skip("no upload") unless upload
      return log_skip("not a video", meta: { id: upload.id, ext: upload.extension }) unless video_upload?(upload)
      return log_skip("already watermarked", meta: { id: upload.id }) if flagged_watermarked?(upload)

      if Discourse.store.respond_to?(:external?) && Discourse.store.external?
        return log_skip("external store (#{Discourse.store.class.name})", meta: { id: upload.id })
      end

      input_path = absolute_local_path_for(upload)
      unless input_path && File.exist?(input_path)
        return log_skip("input file missing", meta: { id: upload.id, input_path: input_path })
      end

      Dir.mktmpdir("video-watermark") do |tmpdir|
        ext = upload.extension.presence || "mp4"
        output_path = File.join(tmpdir, "watermarked-#{upload.id}.#{ext}")

        watermark_image_path = nil

        if SiteSetting.video_watermark_use_image
          # Resolve watermark image path from plugin assets
          watermark_image_path = WATERMARK_IMAGE_PATH
          unless File.exist?(watermark_image_path)
            Rails.logger.error("[VideoWatermark] PNG not found at #{watermark_image_path} - falling back to text")
            watermark_image_path = nil
          end
        end

        cmd = DiscourseVideoWatermark::FFmpegCommand.build(
          input_path: input_path,
          output_path: output_path,
          text: SiteSetting.video_watermark_text,
          # image_url: SiteSetting.video_watermark_image_url,
          image_url: watermark_image_path,
          position: SiteSetting.video_watermark_position,
          fontsize: SiteSetting.video_watermark_fontsize,
          opacity: SiteSetting.video_watermark_opacity
        )

        Rails.logger.info("[VideoWatermark] Running: #{cmd.join(' ')}")
        success = run_ffmpeg(cmd)
        unless success && File.exist?(output_path) && File.size?(output_path)
          Rails.logger.error("[VideoWatermark] FFmpeg failed for upload #{upload.id}")
          return # rubocop:disable Lint/NonLocalExitFromIterator
        end

        FileUtils.mv(output_path, input_path, force: true)
        upload.update_columns(filesize: File.size(input_path))
        set_watermarked_flag!(upload)
        Rails.logger.info("[VideoWatermark] DONE id=#{upload.id} path=#{input_path}")
      end
    end

    private

    # ---- idempotency via plugin-owned model ----
    def flagged_watermarked?(upload)
      ::DiscourseWatermarkVideo::Flag.where(upload_id: upload.id, key: "watermarked").exists?
    end

    def set_watermarked_flag!(upload)
      rec = ::DiscourseWatermarkVideo::Flag.find_or_initialize_by(upload_id: upload.id, key: "watermarked")
      rec.value = "1"
      rec.save!
    end

    # ---- video detection ----
    def video_upload?(upload)
      mt =
        if upload.respond_to?(:content_type)
          upload.content_type
        elsif upload.respond_to?(:mime_type)
          upload.mime_type
        end
      return true if mt&.start_with?("video")
      %w[mp4 mov m4v webm mkv].include?(upload.extension.to_s.downcase)
    end

    def absolute_local_path_for(upload)
      return nil if upload.url.blank?
      File.join(Rails.root, "public", upload.url.sub(%r{\A/}, ""))
    end

    def run_ffmpeg(cmd_array)
      Discourse::Utils.execute_command(*cmd_array)
      true
    rescue => e
      Rails.logger.error("[VideoWatermark] ffmpeg error: #{e.class}: #{e.message}")
      false
    end

    def log_skip(reason, meta: {})
      Rails.logger.info("[VideoWatermark] SKIP #{reason} #{meta.to_json}")
      nil
    end
  end
end