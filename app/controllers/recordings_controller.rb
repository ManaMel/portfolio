class RecordingsController < ApplicationController
  before_action :set_recording, only: [ :show, :destroy, :select_accompaniment, :update_accompaniment, :generate_audio, :generate_video, :destroy_original, :destroy_accompaniment, :destroy_generated ]

  def index
    @recordings = current_user.recordings.order(created_at: :desc)
    @recording = current_user.recordings.new

    if session[:selected_video_id].present?
      @selected_video = Video.find_by(id: session[:selected_video_id])
    end
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

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to mypage_path, notice: "削除しました" }
    end
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

  def destroy_original
    @recording.original_audio.purge
    redirect_back fallback_location: mypage_path, notice: "元の録音を削除しました"
  end

  def destroy_accompaniment
    @recording.accompaniment.purge
    redirect_back fallback_location: mypage_path, notice: "伴奏を削除しました"
  end

  def destroy_generated
    @recording.generated_audio.purge
    redirect_back fallback_location: mypage_path, notice: "生成済み音声を削除しました"
  end

  private

  def recording_params
    params.require(:recording).permit(:title, :original_audio)
  end

  def set_recording
    @recording = current_user.recordings.find(params[:id])
  end
end
