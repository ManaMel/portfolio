class RecordingsController < ApplicationController
  def index
    @video = current_user.videos.last
  end

  def create
    @recording = current_user.recordings.new(recording_params)
    @recording.audio_file.attach(params[:recording][:audio_file]) if params[:recording][:audio_file].present?

    if @recording.save
      render json: { status: "ok" }
    else
      render json: { status: "error" }, status: :unprocessable_entity
    end
  end
  
  private

  def recording_params
    # audio_file は ActiveStorage 添付なので permit には含めなくてもOK
    params.require(:recording).permit(:title)
  end
end
