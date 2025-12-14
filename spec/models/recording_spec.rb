require 'rails_helper'

RSpec.describe Recording, type: :model do
  let(:user) do
    User.create!(
      email: 'test@example.com',
      password: 'password',
      password_confirmation: 'password'
    )
  end

  it '必要な項目が揃っていれば有効である' do
    recording = Recording.new(
      user: user,
      title: 'テスト録音'
    )

    recording.original_audio.attach(
      io: File.open(Rails.root.join('spec/fixtures/files/test.wav')),
      filename: 'test.wav',
      content_type: 'audio/wav'
    )

    expect(recording).to be_valid
  end
end
