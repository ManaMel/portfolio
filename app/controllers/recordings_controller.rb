class RecordingsController < ApplicationController
  def index
    @video = current_user.videos.last
  end
end
