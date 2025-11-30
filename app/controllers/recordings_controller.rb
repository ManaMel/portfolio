class RecordingsController < ApplicationController
  before_action :set_recording, only: [:show, :destroy, :select_accompaniment, :update_accompaniment, :generate_audio, :generate_video]

  def index
    @recordings = current_user.recordings.order(created_at: :desc)
    @recording = current_user.recordings.new
  end

  def create
    @recording = current_user.recordings.new(recording_params)

    if @recording.save
      render json: {
        status: "ok",
        redirect_url: mypage_path
      }
    else
      render json: {
        status: "error",
        errors: @recording.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def show
  end
  
  def destroy
    @recording.destroy
    redirect_to mypage_path, notice: "録音を削除しました"  # ← 一覧へ戻す
  end

  def select_accompaniment
  end

  def update_accompaniment
    if params[:recording] && params[:recording][:accompaniment]
      @recording.accompaniment.attach(params[:recording][:accompaniment])
      redirect_to mypage_path, notice: "伴奏を選択しました"
    else
      redirect_to select_accompaniment_recording_path(@recording), alert: "伴奏ファイルを選択してください"
    end
  end

  def generate_audio
    # 未選択の場合も現在の伴奏を使用
    if params[:recording] && params[:recording][:accompaniment]
      @recording.accompaniment.attach(params[:recording][:accompaniment])
    end

    @recording.start_generation!
    AudioMixingJob.perform_later(@recording.id)

    redirect_to mypage_path, notice: "音声生成を開始しました"
  end

  def generate_video
  end

  private

  def recording_params
    params.require(:recording).permit(:title, :original_audio)
  end

  def set_recording
    @recording = current_user.recordings.find(params[:id])
  end
end
