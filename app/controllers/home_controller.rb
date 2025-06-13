class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    if user_signed_in?
      logger.debug current_user.id
    end
  end
end
