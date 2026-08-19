# A development staff account.
#
# Never seeded outside development: this account can publish to every
# workspace's gallery.
return unless Rails.env.development?

staff = StaffUser.find_or_initialize_by(email: "staff@prachar.test")
staff.assign_attributes(name: "Prachar Studio", password: "correct-horse-battery-staple")
staff.save!

puts "Seeded staff: staff@prachar.test / correct-horse-battery-staple  ->  /admin/login"
