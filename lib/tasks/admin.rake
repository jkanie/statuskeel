namespace :admin do
  desc "Create an admin or reset its password: ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=... bin/rails admin:create"
  task create: :environment do
    email = ENV["ADMIN_EMAIL"].to_s.strip
    password = ENV["ADMIN_PASSWORD"].to_s
    abort "Set ADMIN_EMAIL and ADMIN_PASSWORD." if email.empty? || password.empty?
    abort "ADMIN_PASSWORD must have at least 12 characters." if password.length < 12

    user = User.find_or_initialize_by(email_address: email)
    created = user.new_record?
    user.update!(password:)
    puts "#{created ? "Created" : "Updated"} admin #{user.email_address}."
  end
end
