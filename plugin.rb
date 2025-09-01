# frozen_string_literal: true
# name: discourse-watermark-video
# about: Burn a watermark into uploaded videos (development/local store)
# version: 0.1

enabled_site_setting :video_watermark_enabled

# --- Plugin-owned model mapped to our table (no require needed) ---
module ::DiscourseWatermarkVideo
  class Flag < ActiveRecord::Base
    self.table_name = "discourse_watermark_video_flags"
  end

  module Helpers
    module_function
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
  end
end

after_initialize do
  require_relative "lib/discourse_watermark_video/ffmpeg_command"
  require_relative "app/jobs/regular/watermark_video"
  # require_relative "jobs/regular/watermark_video_external" # if you added the external job

  add_model_callback(:upload, :after_create_commit) do
    next unless SiteSetting.video_watermark_enabled
    next unless ::DiscourseWatermarkVideo::Helpers.video_upload?(self)

    # if using external store, choose the external job (still async unless you also inline that)
    external = Discourse.store.respond_to?(:external?) && Discourse.store.external?

    # idempotency guard (our plugin table)
    already = ::DiscourseWatermarkVideo::Flag.where(upload_id: id, key: "watermarked").exists?
    next if already

    if SiteSetting.video_watermark_inline
      # DEV ONLY: run synchronously
      if external
        Jobs::WatermarkVideoExternal.new.execute(upload_id: id)
      else
        Jobs::WatermarkVideo.new.execute(upload_id: id)
      end
    else
      # normal async path
      job_name = external ? :watermark_video_external : :watermark_video
      Jobs.enqueue(job_name, upload_id: id)
    end
  end
end