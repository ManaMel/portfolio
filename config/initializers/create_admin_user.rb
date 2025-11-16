Rails.application.config.after_initialize do
  # 本番環境だけで実行
  next unless Rails.env.production?

  admin_email = ENV['ADMIN_EMAIL']
  admin_password = ENV['ADMIN_PASSWORD']

  if User.where(admin: true).none?
    if admin_email.present? && admin_password.present?
      User.create!(
        email: admin_email,
        password: admin_password,
        password_confirmation: admin_password,
        admin: true
      )
      Rails.logger.info "[Admin] Admin user created automatically."
    else
      Rails.logger.warn "[Admin] Admin user NOT created. ENV variables missing."
    end
  end
end
