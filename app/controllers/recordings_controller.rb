class RecordingsController < ApplicationController
  def index
    @recordings = current_user.recordings
    @recording = current_user.recordings.new

    if session[:selected_video_id]
      @selected_video = Video.find_by(id: session[:selected_video_id])
    end
  end

  def create
    @recording = current_user.recordings.new(recording_params)

    if @recording.save
      respond_to do |format|
        format.html { redirect_to recordings_path, notice: "録音を保存しました" }
        format.json { render json: { status: "ok", recording_id: @recording.id } }
      end
    else
      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: { status: "error", errors: @recording.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def show
  end

  def destroy
    recording = current_user.recordings.find(params[:id])
    recording.destroy
    redirect_to mypage_path, notice: "録音を削除しました"
  end


  private

  def recording_params
    params.require(:recording).permit(:title, :original_audio)
  end
end
