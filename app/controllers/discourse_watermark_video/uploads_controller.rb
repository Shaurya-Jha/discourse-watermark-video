# frozen_string_literal: true
module DiscourseVideoWatermark
  class UploadsController < ::ApplicationController
    requires_plugin ::DiscourseWatermarkVideo

    requires_login

    def create
      upload = UploadCreator.new(
        params[:file],
        File.basename(params[:file].original_filename)
      ).create_for(current_user.id)

      if upload.errors.any?
        render_json_error(upload.errors.full_messages.join(", "))
      else
        render_json_dump(upload)
      end
    end
  end
end
