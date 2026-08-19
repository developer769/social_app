# The single source of truth for primary navigation, so every screen renders
# the same order with exactly one active item (spec 19, 21).
module Navigation
  ITEMS = [
    { key: :home,      label: "Home",      icon: "home",      route: :workspace_root_path },
    { key: :gallery,   label: "Gallery",   icon: "gallery",   route: nil },
    { key: :create,    label: "Create",    icon: "create",    route: nil },
    { key: :calendar,  label: "Calendar",  icon: "calendar",  route: :workspace_calendar_path },
    { key: :analytics, label: "Analytics", icon: "analytics", route: nil },
    { key: :inbox,     label: "Inbox",     icon: "inbox",     route: nil },
    { key: :ads,       label: "Ads",       icon: "ads",       route: nil },
    { key: :settings,  label: "Settings",  icon: "settings",  route: nil }
  ].freeze

  module_function

  def items
    ITEMS
  end

  # Sections that do not exist yet resolve to the workspace root rather than
  # rendering a dead link.
  def path_for(item, workspace)
    helpers = Rails.application.routes.url_helpers
    return helpers.workspace_root_path(workspace_slug: workspace.slug) if item[:route].nil?

    helpers.public_send(item[:route], workspace_slug: workspace.slug)
  end

  def active?(item, request_path, workspace)
    root = Rails.application.routes.url_helpers.workspace_root_path(workspace_slug: workspace.slug)

    return request_path == root if item[:key] == :home

    request_path.start_with?("#{root}/#{item[:key]}")
  end
end
