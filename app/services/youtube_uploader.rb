class YoutubeUploader
  def initialize(video_generation)
    @video_generation = video_generation
    @youtube = nil
  end
  
  def upload!
    Rails.logger.info "YoutubeUploader: Start uploading video ##{@video_generation.id}"
    
    # 認証設定
    setup_authorization
    
    # 動画ファイルをダウンロード
    video_path = download_video
    
    # YouTube APIにアップロード
    video_object = build_video_object
    
    # ⭐ 修正: upload_source を File.open で開き、content_type を明示
    result = @youtube.insert_video(
      'snippet,status',
      video_object,
      upload_source: video_path,
      content_type: 'video/mp4'  # ← これを追加
    )
    
    # 成功
    youtube_url = "https://www.youtube.com/watch?v=#{result.id}"
    @video_generation.update!(
      youtube_url: youtube_url,
      youtube_video_id: result.id,
      uploaded_to_youtube: true,
      status: :uploaded
    )
    
    Rails.logger.info "YoutubeUploader: Successfully uploaded to #{youtube_url}"
    
    # 一時ファイルを削除
    File.delete(video_path) if File.exist?(video_path)
    
    result
  rescue => e
    Rails.logger.error "YoutubeUploader Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @video_generation.update!(status: :failed, error_message: e.message)
    raise
  end
  
  private
  
  def setup_authorization
    if @video_generation.user_channel?
      setup_user_authorization
    else
      setup_app_authorization
    end
  end
  
  def setup_user_authorization
    Rails.logger.info "YoutubeUploader: Using user channel authorization"
    
    credential = @video_generation.user.youtube_credential
    
    # トークンが有効か確認
    unless credential.valid_token?
      credential.refresh_token!
    end
    
    client = Signet::OAuth2::Client.new(
      client_id: ENV['YOUTUBE_CLIENT_ID'],
      client_secret: ENV['YOUTUBE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      access_token: credential.access_token,
      refresh_token: credential.refresh_token
    )
    
    @youtube = Google::Apis::YoutubeV3::YouTubeService.new
    @youtube.authorization = client
  end
  
  def setup_app_authorization
    Rails.logger.info "YoutubeUploader: Using app channel authorization"
    
    client = Signet::OAuth2::Client.new(
      client_id: ENV['YOUTUBE_APP_CLIENT_ID'],
      client_secret: ENV['YOUTUBE_APP_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      refresh_token: ENV['YOUTUBE_APP_REFRESH_TOKEN']
    )
    
    client.fetch_access_token!
    
    @youtube = Google::Apis::YoutubeV3::YouTubeService.new
    @youtube.authorization = client
  end
  
  def download_video
    tempfile = Tempfile.new(['youtube_upload_', '.mp4'])
    tempfile.binmode
    tempfile.write(@video_generation.generated_video.download)
    tempfile.flush
    tempfile.close
    
    Rails.logger.info "YoutubeUploader: Downloaded video to #{tempfile.path}"
    
    tempfile.path
  end
  
  def build_video_object
    {
      snippet: {
        title: @video_generation.title,
        description: @video_generation.youtube_description,
        tags: build_tags,
        category_id: '10'  # 音楽カテゴリ
      },
      status: {
        privacy_status: 'public',
        self_declared_made_for_kids: false
      }
    }
  end
  
  def build_tags
    tags = ['Mysic', '歌ってみた', 'カバー', 'cover']
    
    # 曲名をタグに追加
    if @video_generation.song_title.present?
      tags << @video_generation.song_title
    end
    
    # アーティスト名をタグに追加
    if @video_generation.original_artist.present?
      tags << @video_generation.original_artist
    end
    
    tags
  end
end