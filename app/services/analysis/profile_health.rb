module Analysis
  # Genuinely computable today: it reads the workspace's own brand profile and
  # catalog, not any social platform.
  class ProfileHealth < Analyzer
    CHECKS = {
      "Business category" => ->(w) { w.brand_profile&.category.present? },
      "Business type" => ->(w) { w.brand_profile&.business_type.present? },
      "Contact email" => ->(w) { w.brand_profile&.contact_email.present? },
      "Phone number" => ->(w) { w.brand_profile&.phone.present? },
      "Location" => ->(w) { w.brand_profile&.city.present? },
      "About your business" => ->(w) { w.brand_profile&.about.present? },
      "Logo" => ->(w) { w.brand_profile&.logo&.attached? },
      "Primary goals" => ->(w) { w.brand_goals.any? },
      "Brand tone" => ->(w) { w.brand_tones.any? },
      "Products or services" => ->(w) { w.products.any? || w.services.any? }
    }.freeze

    def call
      complete = CHECKS.select { |_label, check| check.call(workspace) }.keys
      missing = CHECKS.keys - complete

      Outcome.analysed(
        score: ((complete.size.to_f / CHECKS.size) * 100).round,
        complete: complete,
        missing: missing
      )
    end
  end
end
