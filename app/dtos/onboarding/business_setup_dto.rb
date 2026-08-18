module Onboarding
  # Everything the Business Setup step submits, normalised at the boundary so
  # no raw params hash travels further into the application (spec 11).
  class BusinessSetupDto < ApplicationDto
    attribute :business_name, :category, :business_type, :contact_email, :phone,
              :website_url, :city, :timezone, :about, :goals, :tones, :logo

    def initialize(business_name: nil, category: nil, business_type: nil, contact_email: nil,
                   phone: nil, website_url: nil, city: nil, timezone: nil, about: nil,
                   goals: [], tones: [], logo: nil)
      @business_name = business_name.to_s.strip.presence
      @category = category.to_s.strip.presence
      @business_type = business_type.to_s.strip.presence
      @contact_email = contact_email.to_s.strip.downcase.presence
      @phone = normalise_phone(phone)
      @website_url = CatalogUrl.normalise(website_url)
      @city = city.to_s.strip.presence
      @timezone = timezone.to_s.strip.presence
      @about = about.to_s.strip.presence
      # Unknown values are dropped here rather than reaching a check constraint.
      @goals = Array(goals).map(&:to_s) & BrandGoal::GOALS
      @tones = Array(tones).map(&:to_s) & BrandTone::TONES
      @logo = logo
      freeze
    end

    private

    def normalise_phone(value)
      digits = value.to_s.gsub(/[^\d+]/, "")
      digits.presence
    end
  end
end
