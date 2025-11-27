class VideosController < ApplicationController
  def index
    @video = Video.new
  end

  def create
    @video = current_user.videos.new(video_params)
    if @video.save
      session[:selected_video_id] = @video.id
      redirect_to recordings_path, notice: "動画を選択しました"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    video = current_user.videos.find(params[:id])
    video.destroy!
    redirect_to recordings_path, success: "動画を削除しました", status: :see_other
  end

  def search
    keyword = params[:keyword]
    @results = YoutubeSearchServise.new(keyword).search
    @video = Video.new
    render :index
  end

  private
  def video_params
    params.require(:video).permit(:video_url, :title, :channel)
  end
end
