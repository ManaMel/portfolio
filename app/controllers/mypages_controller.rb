class MypagesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @profile = @user.profile || @user.build_profile
    @recordings = current_user.recordings.order(created_at: :desc)
  end

  private

  def profile_params
    params.require(:profile).permit(:name, :musical_carrer, :avatar)
  end
end
