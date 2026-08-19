module SocialHealth
  # Computes the Social Health score.
  #
  # The score is a weighted average over the components that could actually be
  # measured, and coverage reports how much of the model that was. With no live
  # connected account the three performance signals are unavailable, so the
  # screen shows a score built from part of the model and says exactly that,
  # rather than presenting a confident number partly derived from nothing
  # (spec 22: explain score calculations, do not invent performance claims).
  class Calculator
    RATINGS = [
      [ 80, "excellent" ],
      [ 60, "good" ],
      [ 40, "fair" ],
      [ 0, "needs_work" ]
    ].freeze

    Outcome = Struct.new(:score, :rating, :coverage_percentage, :components, keyword_init: true)

    def self.call(workspace:) = new(workspace: workspace).call

    def initialize(workspace:)
      @workspace = workspace
    end

    def call
      components = [
        profile_completeness,
        catalog_readiness,
        brand_definition,
        account_coverage,
        performance_component("reach", "Reach", 15),
        performance_component("engagement", "Engagement", 15),
        performance_component("posting_consistency", "Posting consistency", 10)
      ]

      measured = components.select(&:measured?)
      total_weight = components.sum(&:weight)
      measured_weight = measured.sum(&:weight)

      score = measured_weight.zero? ? 0 : (measured.sum { |c| c.value * c.weight }.to_f / measured_weight).round

      Outcome.new(
        score: score,
        rating: rating_for(score),
        coverage_percentage: ((measured_weight.to_f / total_weight) * 100).round,
        components: components
      )
    end

    private

    attr_reader :workspace

    def rating_for(score) = RATINGS.find { |threshold, _| score >= threshold }.last

    # ---- Measurable today, from the workspace's own data --------------------

    def profile_completeness
      profile = workspace.brand_profile
      checks = {
        "a business category" => profile&.category.present?,
        "a business type" => profile&.business_type.present?,
        "a contact email" => profile&.contact_email.present?,
        "a phone number" => profile&.phone.present?,
        "a location" => profile&.city.present?,
        "a description of your business" => profile&.about.present?,
        "a logo" => profile&.logo&.attached? || false
      }
      missing = checks.reject { |_, present| present }.keys

      Component.measured(
        key: "profile_completeness", label: "Profile completeness", weight: 20,
        value: ((checks.count { |_, present| present }.to_f / checks.size) * 100).round,
        detail: missing.empty? ? "Your profile is complete." : "Still missing #{missing.to_sentence}.",
        findings: missing.map { |item| { "type" => "attention", "text" => "Add #{item} to your profile." } }
      )
    end

    def catalog_readiness
      products = workspace.products.to_a
      services = workspace.services.to_a
      items = products + services

      return empty_catalog if items.empty?

      described = items.count { |item| item.description.present? }
      priced = products.count { |p| p.price_minor.present? } + services.count { |s| s.starting_price_minor.present? }
      featured = items.count(&:featured?)

      weighted = [
        [ items.size.clamp(0, 5) / 5.0, 0.4 ],
        [ described.to_f / items.size, 0.3 ],
        [ priced.to_f / items.size, 0.2 ],
        [ featured.positive? ? 1.0 : 0.0, 0.1 ]
      ]

      findings = []
      findings << { "type" => "attention", "text" => "Add a short description to every product and service." } if described < items.size
      findings << { "type" => "attention", "text" => "Mark at least one item as featured so it leads your content." } if featured.zero?
      findings << { "type" => "working", "text" => "You have #{items.size} items in your catalog." } if items.size >= 3

      Component.measured(
        key: "catalog_readiness", label: "Catalog readiness", weight: 15,
        value: (weighted.sum { |fraction, weight| fraction * weight } * 100).round,
        detail: "#{items.size} #{'item'.pluralize(items.size)}, #{described} with descriptions.",
        findings: findings
      )
    end

    def empty_catalog
      Component.measured(
        key: "catalog_readiness", label: "Catalog readiness", weight: 15, value: 0,
        detail: "No products or services added yet.",
        findings: [ { "type" => "attention", "text" => "Add your products or services so Prachar can write about them." } ]
      )
    end

    def brand_definition
      goals = workspace.brand_goals.size
      tones = workspace.brand_tones.size

      findings = []
      findings << { "type" => "attention", "text" => "Choose the goals that matter most to you." } if goals.zero?
      findings << { "type" => "attention", "text" => "Choose a brand tone so captions sound like you." } if tones.zero?
      findings << { "type" => "working", "text" => "Your goals and brand tone are set." } if goals.positive? && tones.positive?

      Component.measured(
        key: "brand_definition", label: "Brand definition", weight: 10,
        value: ((((goals.positive? ? 1 : 0) + (tones.positive? ? 1 : 0)) / 2.0) * 100).round,
        detail: "#{goals} #{'goal'.pluralize(goals)}, #{tones} #{'tone'.pluralize(tones)}.",
        findings: findings
      )
    end

    def account_coverage
      accounts = connected_accounts

      if accounts.empty?
        return Component.measured(
          key: "account_coverage", label: "Connected accounts", weight: 15, value: 0,
          detail: "No accounts connected yet.",
          findings: [ { "type" => "attention", "text" => "Connect at least one social account so Prachar can publish for you." } ]
        )
      end

      healthy = accounts.count(&:usable_for_publishing?)
      breadth = accounts.size.clamp(0, 3) / 3.0
      health = healthy.to_f / accounts.size

      findings = [ { "type" => "working", "text" => "#{accounts.size} #{'account'.pluralize(accounts.size)} connected." } ]
      findings << { "type" => "attention", "text" => "Some connections need reauthorising before they can publish." } if healthy < accounts.size
      findings << { "type" => "attention", "text" => "Connecting more platforms widens your reach." } if accounts.size < 3

      Component.measured(
        key: "account_coverage", label: "Connected accounts", weight: 15,
        value: (((breadth * 0.5) + (health * 0.5)) * 100).round,
        detail: "#{healthy} of #{accounts.size} ready to publish.",
        findings: findings
      )
    end

    # ---- Needs a live account with published history ------------------------

    def performance_component(key, label, weight)
      Component.unavailable(key: key, label: label, weight: weight, reason: performance_reason)
    end

    def performance_reason
      return "Connect a social account and this will be measured from your published posts." if connected_accounts.empty?
      return "Your connected accounts are simulated, so there is no real performance history to measure." if connected_accounts.all?(&:mocked?)

      "Not enough published history yet to measure this."
    end

    def connected_accounts
      @connected_accounts ||= workspace.social_accounts.connected.to_a
    end
  end
end
