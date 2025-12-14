class YoutubeCredential < ApplicationRecord
  belongs_to :user

  # トークン（鍵）を暗号化して保存
  encrypts :access_token
  encrypts :refresh_token
  
  # 鍵がまだ有効かチェック
  def valid_token?
    access_token.present? && expires_at > Time.current
  end
  
  # 鍵が切れたら新しい鍵を取得
  def refresh_token!
    client = Signet::OAuth2::Client.new(
      client_id: ENV['YOUTUBE_CLIENT_ID'],
      client_secret: ENV['YOUTUBE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      refresh_token: refresh_token
    )
    
    # 新しい鍵を取得
    client.fetch_access_token!
    
    # データベースを更新
    update!(
      access_token: client.access_token,
      expires_at: Time.current + client.expires_in.seconds
    )
  end
end
