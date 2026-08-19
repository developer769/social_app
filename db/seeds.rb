# Plans are reference data, not development fixtures, so they load in every
# environment before the development-only block below.
load Rails.root.join("db/seeds/plans.rb")

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

  # Brand context, so the analysis step has real data to measure.
  profile = BrandProfile.find_or_initialize_by(workspace: workspace)
  profile.assign_attributes(
    category: "Bakery",
    business_type: "small_business",
    contact_email: "hello@anayabakes.test",
    phone: "+919876543210",
    website_url: "https://anayabakes.test",
    city: "Delhi, India",
    about: "We create fresh, handcrafted bakes using premium ingredients with love and care."
  )
  profile.save!

  %w[increase_sales generate_leads].each do |goal|
    BrandGoal.find_or_create_by!(workspace: workspace, goal: goal)
  end

  %w[friendly elegant].each do |tone|
    BrandTone.find_or_create_by!(workspace: workspace, tone: tone)
  end

  [
    { name: "Chocolate Truffle Cake", category: "Cakes", price_minor: 154_900, featured: true,
      description: "Rich chocolate layers with truffle frosting." },
    { name: "Brownie Box", category: "Brownies", price_minor: 89_900, featured: true,
      description: "Fudgy, chocolatey brownies in a gift box." },
    { name: "Cupcake Box", category: "Cupcakes", price_minor: 69_900,
      description: "Assorted cupcakes in beautiful flavours." },
    { name: "Cookies Pack", category: "Cookies", price_minor: 44_900,
      description: "Crispy, chewy cookies in various flavours." }
  ].each_with_index do |attrs, index|
    product = Product.find_or_initialize_by(workspace: workspace, name: attrs[:name])
    product.assign_attributes(**attrs, currency: "INR", position: index + 1)
    product.save!
  end

  [
    { name: "Custom Birthday Cake Service", category: "Custom Cakes", starting_price_minor: 199_900,
      duration_min_days: 2, duration_max_days: 3, featured: true,
      description: "Personalised cakes for birthdays in your favourite flavours." },
    { name: "Wedding Dessert Table", category: "Events", starting_price_minor: 599_900,
      duration_min_days: 1, duration_max_days: 2, featured: true,
      description: "Elegant dessert tables tailored for weddings and receptions." },
    { name: "Corporate Gift Hampers", category: "Gifting", starting_price_minor: 149_900,
      duration_min_days: 2, duration_max_days: 4,
      description: "Premium hampers for festivals and corporate occasions." }
  ].each_with_index do |attrs, index|
    service = Service.find_or_initialize_by(workspace: workspace, name: attrs[:name])
    service.assign_attributes(**attrs, currency: "INR", position: index + 1)
    service.save!
  end

  workspace.update!(onboarding_step: "connections")

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
