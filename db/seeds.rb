# Development seed data.
#
# "Anaya Bakes" is a fixture for development only, per the specification: the
# platform itself must stay generic, with no bakery-specific behaviour baked in.
return unless Rails.env.development?

ActiveRecord::Base.transaction do
  owner = User.find_or_initialize_by(email: "anaya@anayabakes.test")
  owner.assign_attributes(
    name: "Anaya Sharma",
    password: "correct-horse-battery",
    confirmed_at: Time.current,
    timezone: "Asia/Kolkata"
  )
  owner.save!

  workspace = Workspace.find_or_initialize_by(slug: "anaya-bakes")
  workspace.assign_attributes(
    name: "Anaya Bakes",
    owner_user: owner,
    currency: "INR",
    timezone: "Asia/Kolkata",
    locale: "en-IN",
    country_code: "IN"
  )
  workspace.save!

  WorkspaceMembership.find_or_create_by!(workspace: workspace, user: owner) do |membership|
    membership.invitation_status = "accepted"
    membership.membership_status = "active"
    membership.accepted_at = Time.current
  end

  # A second member, to exercise team listings without inventing any role.
  teammate = User.find_or_initialize_by(email: "rhea@anayabakes.test")
  teammate.assign_attributes(name: "Rhea Nair", password: "correct-horse-battery", confirmed_at: Time.current)
  teammate.save!

  WorkspaceMembership.find_or_create_by!(workspace: workspace, user: teammate) do |membership|
    membership.invitation_status = "accepted"
    membership.membership_status = "active"
    membership.invited_by = owner
    membership.invited_at = 3.days.ago
    membership.accepted_at = 2.days.ago
  end

  # A separate business, so cross-tenant leaks are visible during development.
  other_owner = User.find_or_initialize_by(email: "kabir@kabircoffee.test")
  other_owner.assign_attributes(name: "Kabir Rao", password: "correct-horse-battery", confirmed_at: Time.current)
  other_owner.save!

  other = Workspace.find_or_initialize_by(slug: "kabir-coffee")
  other.assign_attributes(name: "Kabir Coffee", owner_user: other_owner)
  other.save!

  WorkspaceMembership.find_or_create_by!(workspace: other, user: other_owner) do |membership|
    membership.invitation_status = "accepted"
    membership.membership_status = "active"
    membership.accepted_at = Time.current
  end
end

puts "Seeded: anaya@anayabakes.test / correct-horse-battery  ->  /w/anaya-bakes"
puts "Seeded: kabir@kabircoffee.test  (separate tenant, for isolation checks)"
