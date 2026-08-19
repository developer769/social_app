module PlansHelper
  # The design reads "Pick the plan that fits your bakery business best", but
  # the platform is generic, so the category comes from the workspace rather
  # than being written into the view (spec 19).
  def plan_subtitle(workspace)
    category = workspace.brand_profile&.category.presence&.downcase

    if category
      "Pick the plan that fits your #{category} business best. Cancel anytime."
    else
      "Pick the plan that fits your business best. Cancel anytime."
    end
  end
end
