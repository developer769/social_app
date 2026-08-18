# The single definition of the onboarding journey, so the wizard, the progress
# bar and the resume logic cannot disagree about what comes next.
#
# Six steps, per specification 22. The supplied screens disagree with
# themselves here -- Business Setup is labelled "Step 1 of 5", Products &
# Services "Step 2 of 6" -- so the specification decides. Goals and brand tones
# are collected inside Business Setup, which is what the Business Setup screen
# itself shows.
module OnboardingFlow
  STEPS = [
    { key: "business_setup", label: "Business setup", path: :workspace_onboarding_business_path },
    { key: "catalog",        label: "Products and services", path: :workspace_onboarding_catalog_path },
    { key: "connections",    label: "Social connections", path: :workspace_onboarding_connections_path },
    { key: "analysis",       label: "Brand analysis", path: :workspace_onboarding_analysis_path },
    { key: "health",         label: "Social health", path: :workspace_onboarding_health_path },
    { key: "plan",           label: "Choose a plan", path: :workspace_onboarding_plan_path }
  ].freeze

  KEYS = STEPS.map { |step| step[:key] }.freeze

  module_function

  def steps = STEPS
  def keys = KEYS

  def step(key) = STEPS.find { |candidate| candidate[:key] == key.to_s }

  def index_of(key) = KEYS.index(key.to_s)

  def first_key = KEYS.first

  def next_key(key)
    index = index_of(key)
    return "completed" if index.nil? || index >= KEYS.length - 1

    KEYS[index + 1]
  end

  def previous_key(key)
    index = index_of(key)
    return if index.nil? || index.zero?

    KEYS[index - 1]
  end

  # Progress only ever moves forward, so revisiting an earlier step to correct
  # something does not throw away later work.
  def furthest(current, candidate)
    return "completed" if current == "completed" || candidate == "completed"

    (index_of(candidate).to_i > index_of(current).to_i) ? candidate : current
  end

  def path_for(key, workspace)
    definition = step(key)
    return Rails.application.routes.url_helpers.workspace_root_path(workspace_slug: workspace.slug) if definition.nil?

    Rails.application.routes.url_helpers.public_send(definition[:path], workspace_slug: workspace.slug)
  end
end
