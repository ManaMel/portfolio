require 'google/apis/youtube_v3'
require 'signet/oauth_2/client'

class YoutubeUploader
  # 初期化
  def initialize(video_generation)
    @video_generation = video_generation
    @user = video_generation.user
    @youtube = Google::Apis::YoutubeV3::YouTubeService.new
  end
  
  # メインのアップロード処理
  def upload!
    Rails.logger.info "YoutubeUploader: Start uploading video_generation ##{@video_generation.id}"
    
    # 1. 認証情報をセットアップ
    setup_authorization
    
    # 2. 動画ファイルを一時的にダウンロード
    video_path = download_video
    
    # 3. YouTube用の動画情報を作成
    video_object = build_video_object
    
    # 4. YouTubeにアップロード
    result = @youtube.insert_video(
      'snippet,status',
      video_object,
      upload_source: video_path,
      content_type: 'video/mp4'
    )
    
    # 5. URLを生成
    youtube_url = "https://www.youtube.com/watch?v=#{result.id}"
    
    # 6. データベースを更新
    @video_generation.update!(
      youtube_url: youtube_url,
      youtube_video_id: result.id,
      uploaded_to_youtube: true,
      status: :uploaded
    )
    
    Rails.logger.info "YoutubeUploader: Successfully uploaded to #{youtube_url}"
    
    youtube_url
    
  rescue => e
    Rails.logger.error "YoutubeUploader Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @video_generation.update!(
      status: :failed,
      error_message: "YouTube Upload Error: #{e.message}"
    )
    raise
  ensure
    # 最後に一時ファイルを削除
    File.delete(video_path) if video_path && File.exist?(video_path)
  end
  
  private
  
  # 認証情報をセットアップ
  def setup_authorization
    if @video_generation.user_channel?
      setup_user_authorization
    else
      setup_app_authorization
    end
  end
  
  # ユーザーチャンネル用の認証
  def setup_user_authorization
    credential = @user.youtube_credential
    
    # トークンが期限切れなら更新
    credential.refresh_token! unless credential.valid_token?
    
    @youtube.authorization = Signet::OAuth2::Client.new(
      client_id: ENV['YOUTUBE_CLIENT_ID'],
      client_secret: ENV['YOUTUBE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      access_token: credential.access_token,
      refresh_token: credential.refresh_token,
      expires_at: credential.expires_at
    )
    
    Rails.logger.info "YoutubeUploader: Using user channel authorization"
  end
  
  # アプリチャンネル用の認証
  def setup_app_authorization
    client = Signet::OAuth2::Client.new(
      client_id: ENV['YOUTUBE_APP_CLIENT_ID'],
      client_secret: ENV['YOUTUBE_APP_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      refresh_token: ENV['YOUTUBE_APP_REFRESH_TOKEN']
    )
    
    client.fetch_access_token!
    
    @youtube.authorization = client
    
    Rails.logger.info "YoutubeUploader: Using app channel authorization"
  end
  
  # YouTube用の動画情報を作成
  def build_video_object
    description = @video_generation.body.to_s
    
    # アプリチャンネルの場合はクレジット追加
    if @video_generation.app_channel?
      description += "\n\n---\n"
      description += "Created by: #{@user.email}\n"
      description += "App: Mysic\n"
    end
    
    description += "\n#Mysic #歌ってみた #カラオケ"
    
    {
      snippet: {
        title: @video_generation.title,
        description: description,
        tags: ['Mysic', '歌ってみた', 'カラオケ', '音楽'],
        category_id: '10' # 音楽カテゴリ
      },
      status: {
        privacy_status: 'public',
        self_declared_made_for_kids: false
      }
    }
  end
  
  # 動画を一時ファイルにダウンロード
  def download_video
    temp_file = Tempfile.new(['youtube_upload', '.mp4'])
    temp_file.binmode
    temp_file.write(@video_generation.generated_video.download)
    temp_file.flush
    temp_file.path
  end
end
