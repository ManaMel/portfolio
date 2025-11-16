if User.where(admin: true).none?
  admin_email = ENV["ADMIN_EMAIL"]
  admin_password = ENV["ADMIN_PASSWORD"]

  if admin_email.present? && admin_password.present?
    User.create!(
      email: admin_email,
      password: admin_password,
      password_confirmation: admin_password,
      admin: true
    )
    Rails.logger.info "Admin user created automatically."
  else
    Rails.logger.warn "Admin user NOT created. ENV variables missing."
  end
end
