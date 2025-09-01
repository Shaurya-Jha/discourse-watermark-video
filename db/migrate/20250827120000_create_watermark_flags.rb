# frozen_string_literal: true
class CreateWatermarkFlags < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_watermark_video_flags do |t|
      t.bigint :upload_id, null: false
      t.string :key, null: false
      t.string :value
      t.timestamps null: false
    end

    add_index :discourse_watermark_video_flags, [:upload_id, :key], unique: true, name: "idx_wm_flags_upload_key"
    add_index :discourse_watermark_video_flags, :upload_id
  end
end