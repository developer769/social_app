# The single source of truth for primary navigation, so every screen renders
# the same order with exactly one active item (spec 19, 21).
#
# An item with no route is NOT yet built. It used to fall back to the workspace
# root, which meant six of the eight items silently returned you to Home and
# the whole product read as broken rather than unfinished. Unbuilt sections now
# render as plainly unavailable.
module Navigation
  ITEMS = [
    { key: :home,      label: "Home",      icon: "home",      route: :workspace_root_path },
    { key: :gallery,   label: "Gallery",   icon: "gallery",   route: :workspace_gallery_path },
    { key: :create,    label: "Create",    icon: "create",    route: :workspace_create_path },
    { key: :calendar,  label: "Calendar",  icon: "calendar",  route: :workspace_calendar_path },
    { key: :analytics, label: "Analytics", icon: "analytics", route: :workspace_analytics_path },
    { key: :inbox,     label: "Inbox",     icon: "inbox",     route: nil },
    { key: :ads,       label: "Ads",       icon: "ads",       route: nil },
    { key: :settings,  label: "Settings",  icon: "settings",  route: :workspace_settings_root_path }
  ].freeze

  module_function

  def items = ITEMS

  def available?(item) = item[:route].present?

  def path_for(item, workspace)
    return nil unless available?(item)

    Rails.application.routes.url_helpers.public_send(item[:route], workspace_slug: workspace.slug)
  end

  def active?(item, request_path, workspace)
    return false unless available?(item)

    path = path_for(item, workspace)
    return request_path == path if item[:key] == :home

    request_path.start_with?(path)
  end
end
