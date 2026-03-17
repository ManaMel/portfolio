if Rails.env.development?
  LetterOpener.configure do |config|
    # 自動ブラウザ起動を無効化
    config.location = Rails.root.join("tmp", "letter_opener")
  end
end
