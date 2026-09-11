# The single definition of the onboarding journey, so the wizard, the progress
# bar and the resume logic cannot disagree about what comes next.
#
# Six steps for a business, per specification 22. The supplied screens disagree
# with themselves here -- Business Setup is labelled "Step 1 of 5", Products &
# Services "Step 2 of 6" -- so the specification decides. Goals and brand tones
# are collected inside Business Setup, which is what the Business Setup screen
# itself shows.
#
# An influencer walks a shorter path. The first two steps ask a business about
# its legal type, its category and the products it sells, and a creator has
# none of those -- so rather than showing them empty forms to skip past, those
# steps are not part of their journey at all. Every function here therefore
# takes the account type, and the numbering follows: a creator sees "Step 1 of
# 4", not "Step 3 of 6" with two steps they never did.
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

  # Steps that do not apply to an account type. Anything not listed walks the
  # full journey, so a new account type added later gets the whole thing until
  # somebody decides otherwise -- which is the safe default.
  SKIPPED = { "influencer" => %w[business_setup catalog].freeze }.freeze

  module_function

  def skipped_for(account_type) = SKIPPED.fetch(account_type.to_s, [])

  def steps(account_type = nil)
    skipped = skipped_for(account_type)
    return STEPS if skipped.empty?

    STEPS.reject { |step| skipped.include?(step[:key]) }
  end

  def keys(account_type = nil)
    skipped = skipped_for(account_type)
    return KEYS if skipped.empty?

    KEYS - skipped
  end

  def step(key) = STEPS.find { |candidate| candidate[:key] == key.to_s }

  def index_of(key, account_type = nil) = keys(account_type).index(key.to_s)

  def first_key(account_type = nil) = keys(account_type).first

  def includes?(key, account_type = nil) = keys(account_type).include?(key.to_s)

  # Where somebody actually belongs right now. A workspace can hold a step that
  # is not on its own path -- an account created before the type existed, or one
  # whose type was changed -- and sending them to a step their journey does not
  # contain would strand them on a form the rest of the flow never returns to.
  def resolve(key, account_type = nil)
    return "completed" if key.to_s == "completed"

    includes?(key, account_type) ? key.to_s : first_key(account_type)
  end

  def next_key(key, account_type = nil)
    list = keys(account_type)
    index = list.index(key.to_s)
    return "completed" if index.nil? || index >= list.length - 1

    list[index + 1]
  end

  def previous_key(key, account_type = nil)
    list = keys(account_type)
    index = list.index(key.to_s)
    return if index.nil? || index.zero?

    list[index - 1]
  end

  # Progress only ever moves forward, so revisiting an earlier step to correct
  # something does not throw away later work.
  def furthest(current, candidate, account_type = nil)
    return "completed" if current == "completed" || candidate == "completed"

    list = keys(account_type)
    # A step outside this journey sorts before everything in it, so a legacy
    # value can never pin progress above where the owner has actually reached.
    current_index = list.index(current.to_s) || -1
    candidate_index = list.index(candidate.to_s) || -1

    candidate_index > current_index ? candidate.to_s : current.to_s
  end

  def path_for(key, workspace)
    definition = step(resolve(key, workspace&.account_type))
    return Rails.application.routes.url_helpers.workspace_root_path(workspace_slug: workspace.slug) if definition.nil?

    Rails.application.routes.url_helpers.public_send(definition[:path], workspace_slug: workspace.slug)
  end
end
