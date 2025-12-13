class VideoGeneration < ApplicationRecord
  belongs_to :user
  belongs_to :recording

  has_one_attached :thumbnail_image
  has_one_attached :generated_video

  enum status: {
    created: 0,
    ready: 1,
    generating: 2,
    generated: 3,
    failed: 4,
    uploading: 5,
    uploaded: 6
  }

  enum upload_destination: {
    user_channel: 0,
    app_channel: 1
  }

  validates :title, presence: true
  validates :body, length: { maximum: 1000 }, allow_blank: true

  def youtube_description
    desc = []
    
    desc << body if body.present?
    desc << ""

    if has_song_info?
      desc << "=" * 40
      desc << "【楽曲情報】"
      desc << "曲名: #{song_title}"
      desc << "原曲: #{original_artist}"
      desc << "作曲: #{composer}" if composer.present?
      desc << "作詞: #{lyricist}" if lyricist.present?
      desc << ""
      desc << "カバー: #{user.email}"
      desc << "=" * 40
      desc << ""

      if copyright_notes.present?
        desc << "【権利情報】"
        desc << copyright_notes
        desc << ""
      end
      
      desc << "※この動画はカバー音源です"
      desc << "※原曲の著作権は原作者に帰属します"
    end
    
    if app_channel?
      desc << ""
      desc << "---"
      desc << "Created by: #{user.email}"
      desc << "App: Mysic"
    end
    
    desc << ""
    desc << "#カバー #歌ってみた #Mysic"
    
    desc.join("\n")
  end
  

  def has_song_info?
    song_title.present? && original_artist.present?
  end

  def ready_for_generation?
    recording&.generated_audio&.attached? && thumbnail_image.attached?
  end

  def ready_for_youtube_upload?
    generated? && generated_video.attached?
  end

  def can_upload_to_user_channel?
    user.youtube_authenticated?
  end
end
