module SocialHealthHelper
  SUMMARIES = {
    "excellent" => "Your setup is in excellent shape. Keep the momentum going.",
    "good" => "You are in good shape and building a solid foundation. A few areas will lift you further.",
    "fair" => "You have made a start. Filling the gaps below will make a noticeable difference.",
    "needs_work" => "There is groundwork to do before Prachar can work well for you. Start with the items below."
  }.freeze

  def health_summary(score)
    SUMMARIES.fetch(score.rating, SUMMARIES["needs_work"])
  end

  # Every recommendation traces back to a component that scored below full
  # marks, so nothing here is generic advice (spec 22: no invented claims).
  def health_recommendations(score, workspace)
    slug = { workspace_slug: workspace.slug }

    score.measured_components
         .reject { |component| component["value"].to_i >= 100 }
         .sort_by { |component| component["value"].to_i }
         .filter_map { |component| recommendation_for(component, slug) }
  end

  private

  def recommendation_for(component, slug)
    case component["key"]
    when "profile_completeness"
      { title: "Complete your business profile", glyph: "\u270E",
        body: component["detail"], path: workspace_onboarding_business_path(**slug) }
    when "catalog_readiness"
      { title: "Strengthen your catalog", glyph: "\u25A6",
        body: component["detail"], path: workspace_onboarding_catalog_path(**slug) }
    when "brand_definition"
      { title: "Define your goals and tone", glyph: "\u2726",
        body: component["detail"], path: workspace_onboarding_business_path(**slug) }
    when "account_coverage"
      { title: "Connect your social accounts", glyph: "\u26AD",
        body: component["detail"], path: workspace_onboarding_connections_path(**slug) }
    end
  end
end
