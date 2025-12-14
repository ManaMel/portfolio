require 'rails_helper'

RSpec.describe 'ユーザーログイン', type: :system do
  before do
    skip 'Docker環境ではSelenium未設定のためスキップ'
  end
  
  it 'ログインできる' do
    User.create!(
      email: 'test@example.com',
      password: 'password',
      password_confirmation: 'password'
    )

    visit new_user_session_path

    fill_in 'user[email]', with: 'test@example.com'
    fill_in 'user[password]', with: 'password'
    click_button 'ログイン'

    expect(page).to have_content('ログアウト')
  end
end
