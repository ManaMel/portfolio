class RecordingsController < ApplicationController
  def index
    @videos = Video.all
  end
end
