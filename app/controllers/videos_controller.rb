class VideosController < ApplicationController
  def index
  end

  def new
    @video = Video.new
  end

  def create
    @video = current_user.videos.new(video_params)
    if @video.save
      redirect_to recordings_path, notice: '伴奏動画を選択しました'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    video = current_user.videos.find(params[:id])
    video.destroy!
    redirect_to recordings_path, success: '伴奏動画を削除しました', status: :see_other
  end

  private
  def video_params
    params.require(:video).permit(:video_url)
  end
end
