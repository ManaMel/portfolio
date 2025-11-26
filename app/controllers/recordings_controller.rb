class RecordingsController < ApplicationController
  def index
    @recordings = current_user.recordings
    @recording = current_user.recordings.new
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

  private

  def recording_params
    params.require(:recording).permit(:title, :original_audio)
  end
end
