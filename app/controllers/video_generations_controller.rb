class VideoGenerationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_video_generation, only: [:show, :update, :generate, :destroy]

  def index
    # ミキシング済みのRecordingを取得
    @recordings = current_user.recordings.where(status: :generated).order(created_at: :desc)
  end

  def new
    @recording = current_user.recordings.find(params[:recording_id])

    unless @recording.generated?
      redirect_to video_generations_path, alert: '選択された録音はまだミキシングが完了していません。'
      return
    end

    @video_generation = VideoGeneration.new(recording: @recording)
  end

  def create
    @video_generation = current_user.video_generations.new(video_generation_params)
    @video_generation.status = :created

    if @video_generation.save
      redirect_to @video_generation, notice: '動画プロジェクトを作成しました。サムネイル画像をアップロードしてください。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # 生成済みの動画を表示、または画像アップロード
  end

  def update
    if @video_generation.update(video_generation_params)
      @video_generation.update(status: :ready) if @video_generation.ready_for_generation?
      redirect_to @video_generation, notice: 'サムネイル画像をアップロードしました。'
    else
      render :show, status: :unprocessable_entity
    end
  end

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
