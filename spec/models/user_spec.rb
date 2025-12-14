require 'rails_helper'

RSpec.describe User, type: :model do
  it '有効なユーザーは保存できる' do
    user = User.new(
      email: 'test@example.com',
      password: 'password',
      password_confirmation: 'password'
    )

    expect(user).to be_valid
  end
end
