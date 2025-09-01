# frozen_string_literal: true
module DiscourseWatermarkVideo
  class Flag < ActiveRecord::Base
    self.table_name = "discourse_watermark_video_flags"
  end
end