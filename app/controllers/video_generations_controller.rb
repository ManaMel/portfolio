class VideoGenerationsController < ApplicationController
  def index
    @recordings = current_user.recordings.order(created_at: :desc)
  end

  def generate_audio
    recording = current_user.recordings.find(params[:recording_id])
    accomp_file = params[:accompaniment]

    if accomp_file.present?
      recording.accompaniment.attach(accomp_file)
    end

    AudioMixingJob.perform_later(recording.id)

    redirect_to video_generations_path, notice: "音声生成を開始しました"
  end
end
