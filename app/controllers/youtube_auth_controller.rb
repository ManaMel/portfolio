class YoutubeAuthController < ApplicationController
  before_action :authenticate_user!, except: [:app_channel_callback]
  
  # ========================================
  # ユーザー認証（既存のコード）
  # ========================================
  
  def new
    redirect_to oauth_client.authorization_uri.to_s, allow_other_host: true
  end
  
  def callback
    oauth_client.code = params[:code]
    oauth_client.fetch_access_token!
    
    current_user.create_youtube_credential!(
      access_token: oauth_client.access_token,
      refresh_token: oauth_client.refresh_token,
      expires_at: Time.current + oauth_client.expires_in.seconds
    )
    
    redirect_to video_generations_path, notice: 'YouTube認証が完了しました。'
  rescue => e
    redirect_to video_generations_path, alert: "認証に失敗しました: #{e.message}"
  end
  
  # ========================================
  # アプリチャンネル認証（新規追加）
  # ========================================
  
  def app_channel_callback
    begin
      client = Signet::OAuth2::Client.new(
        client_id: ENV['YOUTUBE_APP_CLIENT_ID'],
        client_secret: ENV['YOUTUBE_APP_CLIENT_SECRET'],
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        redirect_uri: youtube_app_channel_callback_url,
        code: params[:code]
      )
      
      client.fetch_access_token!
      
      # 成功メッセージを表示
      render html: generate_success_page(client.refresh_token).html_safe
      
    rescue => e
      render html: generate_error_page(e.message).html_safe
    end
  end
  
  private
  
  def oauth_client
    @oauth_client ||= Signet::OAuth2::Client.new(
      client_id: ENV['YOUTUBE_CLIENT_ID'],
      client_secret: ENV['YOUTUBE_CLIENT_SECRET'],
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      scope: 'https://www.googleapis.com/auth/youtube.upload',
      redirect_uri: youtube_callback_url
    )
  end
  
  def generate_success_page(refresh_token)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>リフレッシュトークン取得成功</title>
        <style>
          body {
            font-family: 'Courier New', monospace;
            padding: 40px;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #00ff00;
            min-height: 100vh;
          }
          .container {
            max-width: 900px;
            margin: 0 auto;
            background: rgba(0, 0, 0, 0.8);
            padding: 40px;
            border: 3px solid #00ff00;
            border-radius: 12px;
            box-shadow: 0 0 30px rgba(0, 255, 0, 0.3);
          }
          h1 {
            color: #00ff00;
            text-align: center;
            font-size: 2em;
            margin-bottom: 10px;
            text-shadow: 0 0 10px #00ff00;
          }
          .success-icon {
            text-align: center;
            font-size: 4em;
            margin: 20px 0;
          }
          .section {
            margin: 30px 0;
            padding: 20px;
            background: rgba(0, 40, 0, 0.5);
            border: 1px solid #00ff00;
            border-radius: 8px;
          }
          .section h3 {
            color: #00ff00;
            margin-top: 0;
            font-size: 1.3em;
          }
          .token {
            background: #000;
            padding: 15px;
            margin: 15px 0;
            border: 2px solid #00ff00;
            border-radius: 5px;
            word-break: break-all;
            font-size: 0.9em;
            position: relative;
          }
          .copy-btn {
            background: #00ff00;
            color: #000;
            border: none;
            padding: 10px 20px;
            cursor: pointer;
            font-family: 'Courier New', monospace;
            font-weight: bold;
            border-radius: 5px;
            transition: all 0.3s;
            margin-top: 10px;
          }
          .copy-btn:hover {
            background: #00dd00;
            transform: scale(1.05);
            box-shadow: 0 0 15px rgba(0, 255, 0, 0.5);
          }
          .warning {
            background: rgba(255, 0, 0, 0.2);
            border: 2px solid #ff0000;
            padding: 20px;
            margin: 20px 0;
            border-radius: 8px;
            color: #ff6666;
          }
          .step {
            background: rgba(0, 60, 0, 0.3);
            padding: 15px;
            margin: 10px 0;
            border-left: 4px solid #00ff00;
            border-radius: 4px;
          }
          .step-number {
            display: inline-block;
            background: #00ff00;
            color: #000;
            width: 30px;
            height: 30px;
            line-height: 30px;
            text-align: center;
            border-radius: 50%;
            font-weight: bold;
            margin-right: 10px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="success-icon">✓</div>
          <h1>認証成功！</h1>
          <p style="text-align: center; color: #aaa;">アプリチャンネル用のリフレッシュトークンを取得しました</p>
          
          <div class="section">
            <h3>取得した情報</h3>
            
            <p><strong>クライアントID:</strong></p>
            <div class="token" id="client-id">#{ENV['YOUTUBE_APP_CLIENT_ID']}</div>
            <button class="copy-btn" onclick="copyToClipboard('client-id')">コピー</button>
            
            <p><strong>クライアントシークレット:</strong></p>
            <div class="token" id="client-secret">#{ENV['YOUTUBE_APP_CLIENT_SECRET']}</div>
            <button class="copy-btn" onclick="copyToClipboard('client-secret')">コピー</button>
            
            <p><strong>リフレッシュトークン:</strong></p>
            <div class="token" id="refresh-token">#{refresh_token}</div>
            <button class="copy-btn" onclick="copyToClipboard('refresh-token')">コピー</button>
          </div>
          
          <div class="section">
            <h3>次の手順</h3>
            
            <div class="step">
              <span class="step-number">1</span>
              <strong>.env ファイルを開く</strong>
              <pre style="margin: 10px 0 0 40px; color: #aaa;">code .env</pre>
            </div>
            
            <div class="step">
              <span class="step-number">2</span>
              <strong>以下の行を追加</strong>
              <div class="token" id="all-env" style="margin: 10px 0 0 40px;">YOUTUBE_APP_REFRESH_TOKEN=#{refresh_token}</div>
              <button class="copy-btn" onclick="copyToClipboard('all-env')" style="margin-left: 40px;">コピー</button>
            </div>
            
            <div class="step">
              <span class="step-number">3</span>
              <strong>ファイルを保存</strong>
            </div>
            
            <div class="step">
              <span class="step-number">4</span>
              <strong>サーバーを再起動</strong>
              <pre style="margin: 10px 0 0 40px; color: #aaa;">docker compose restart web worker</pre>
            </div>
            
            <div class="step">
              <span class="step-number">5</span>
              <strong>このページを閉じる</strong>
            </div>
          </div>
          
          <div class="warning">
            <strong>⚠️ 重要な注意事項</strong>
            <ul>
              <li>このページは一度閉じると二度と表示されません</li>
              <li>必ずリフレッシュトークンをコピーしてから閉じてください</li>
              <li>.env ファイルは Git にコミットしないでください</li>
              <li>トークンは誰にも見せないでください</li>
            </ul>
          </div>
        </div>
        
        <script>
          function copyToClipboard(elementId) {
            const element = document.getElementById(elementId);
            const text = element.textContent.trim();
            
            navigator.clipboard.writeText(text).then(() => {
              const btn = event.target;
              const originalText = btn.textContent;
              btn.textContent = '✓ コピーしました！';
              btn.style.background = '#00dd00';
              
              setTimeout(() => {
                btn.textContent = originalText;
                btn.style.background = '#00ff00';
              }, 2000);
            }).catch(err => {
              alert('コピーに失敗しました。手動でコピーしてください。');
              console.error('コピーエラー:', err);
            });
          }
        </script>
      </body>
      </html>
    HTML
  end
  
  def generate_error_page(error_message)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>エラー</title>
        <style>
          body {
            font-family: 'Courier New', monospace;
            padding: 40px;
            background: linear-gradient(135deg, #2e1a1a 0%, #3e1616 100%);
            color: #ff6666;
            min-height: 100vh;
          }
          .container {
            max-width: 800px;
            margin: 0 auto;
            background: rgba(0, 0, 0, 0.8);
            padding: 40px;
            border: 3px solid #ff0000;
            border-radius: 12px;
            box-shadow: 0 0 30px rgba(255, 0, 0, 0.3);
          }
          h1 {
            color: #ff0000;
            text-align: center;
            text-shadow: 0 0 10px #ff0000;
          }
          .error-icon {
            text-align: center;
            font-size: 4em;
            margin: 20px 0;
          }
          .error-message {
            background: rgba(40, 0, 0, 0.5);
            padding: 20px;
            border: 1px solid #ff0000;
            border-radius: 8px;
            margin: 20px 0;
          }
          .back-btn {
            display: block;
            width: 200px;
            margin: 30px auto;
            padding: 15px;
            background: #ff0000;
            color: #fff;
            text-align: center;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="error-icon">✗</div>
          <h1>エラーが発生しました</h1>
          
          <div class="error-message">
            <strong>エラー内容:</strong><br>
            #{error_message}
          </div>
          
          <p>もう一度最初からやり直してください。</p>
          
          <a href="/" class="back-btn">ホームに戻る</a>
        </div>
      </body>
      </html>
    HTML
  end
end