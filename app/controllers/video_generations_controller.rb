# app/controllers/video_generations_controller.rb

class VideoGenerationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_video_generation, only: [:show, :update, :generate, :upload_to_youtube, :destroy]

  # 一覧ページ（録音を選択）
  def index
    # ミキシング済みのRecordingを取得
    @recordings = current_user.recordings.where(status: :generated).order(created_at: :desc)
  end

  # タイトル入力ページ
  def new
    @recording = current_user.recordings.find(params[:recording_id])
    
    unless @recording.generated?
      redirect_to video_generations_path, alert: '選択された録音はまだミキシングが完了していません。'
      return
    end
    
    @video_generation = VideoGeneration.new(recording: @recording)
  end

  # プロジェクト作成
  def create
    @video_generation = current_user.video_generations.new(video_generation_params)
    @video_generation.status = :created
    
    if @video_generation.save
      redirect_to @video_generation, notice: '動画プロジェクトを作成しました。サムネイル画像をアップロードしてください。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # 詳細・編集ページ
  def show
    # YouTube認証状態をチェック
    @can_upload_to_user_channel = @video_generation.can_upload_to_user_channel?
  end

  # サムネイル画像をアップロード
  def update
    if @video_generation.update(video_generation_params)
      @video_generation.update(status: :ready) if @video_generation.ready_for_generation?
      redirect_to @video_generation, notice: 'サムネイル画像をアップロードしました。'
    else
      render :show, status: :unprocessable_entity
    end
  end

  # 動画生成開始
  def generate
    unless @video_generation.ready_for_generation?
      redirect_to @video_generation, alert: '動画生成の準備が整っていません。'
      return
    end
    
    @video_generation.update!(status: :generating)
    
    begin
      VideoGenerationJob.perform_later(@video_generation.id)
      redirect_to @video_generation, notice: '動画生成を開始しました。完了までしばらくお待ちください。'
    rescue => e
      Rails.logger.error "VideoGenerationsController#generate: #{e.message}"
      @video_generation.update!(status: :failed, error_message: e.message)
      redirect_to @video_generation, alert: '動画生成の開始に失敗しました。'
    end
  end

  # YouTubeアップロード開始（★ これが追加されていませんでした）
  def upload_to_youtube
    unless @video_generation.ready_for_youtube_upload?
      redirect_to @video_generation, alert: '動画がまだ生成されていません。'
      return
    end
    
    destination = params[:destination] # 'user_channel' or 'app_channel'
    
    # ユーザーチャンネルを選択したが認証されていない場合
    if destination == 'user_channel' && !current_user.youtube_authenticated?
      redirect_to youtube_auth_path, alert: 'YouTube認証が必要です。'
      return
    end
    
    @video_generation.update!(upload_destination: destination)
    
    YoutubeUploadJob.perform_later(@video_generation.id)
    
    redirect_to @video_generation, notice: 'YouTubeへのアップロードを開始しました。'
  end

  # 削除
  def destroy
    @video_generation.destroy
    redirect_to video_generations_path, notice: '動画プロジェクトを削除しました。'
  end

  private

  def set_video_generation
    @video_generation = current_user.video_generations.find_by(id: params[:id])
    unless @video_generation
      redirect_to video_generations_path, alert: '指定された動画プロジェクトが見つかりません。'
    end
  end

  def video_generation_params
    params.require(:video_generation).permit(:title, :body, :recording_id, :thumbnail_image)
  end
end
