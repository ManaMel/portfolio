admin_email = ENV["ADMIN_EMAIL"]
admin_password = ENV["ADMIN_PASSWORD"]

if User.where(admin: true).none?
  if admin_email.present? && admin_password.present?
    User.create!(
      email: admin_email,
      password: admin_password,
      password_confirmation: admin_password,
      admin: true
    )
    puts "[Admin] Admin user created automatically."
  else
    puts "[Admin] Admin user NOT created. ENV variables missing."
  end
end

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
