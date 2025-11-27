class MypagesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @profile = @user.profile || @user.build_profile
    @recordings = current_user.recordings.order(created_at: :desc)
  end

  def edit
    @profile = current_user.profile || current_user.build_profile
  end

  def update
    @profile = current_user.profile || current_user.build_profile
    if @profile.update(profile_params)
        redirect_to mypage_path, notice: "プロフィールを更新しました"
    else
        render :edit
    end
  end

  private

  def profile_params
    params.require(:profile).permit(:name, :musical_carrer, :avatar)
  end
end
