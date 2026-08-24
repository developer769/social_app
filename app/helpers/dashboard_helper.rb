module DashboardHelper
  # Where each dashboard card sends you. Kept in one place so a card and the
  # thing it describes can never drift apart.
  def dashboard_path_for(key)
    slug = { workspace_slug: current_workspace.slug }

    case key
    when :analytics then workspace_analytics_path(**slug)
    when :calendar then workspace_calendar_path(**slug)
    when :inbox then workspace_inbox_path(**slug)
    when :create then workspace_create_path(**slug)
    when :connections then workspace_settings_connections_path(**slug)
    when :catalog then workspace_settings_catalog_path(**slug)
    else workspace_root_path(**slug)
    end
  end

  ATTENTION_TONES = {
    critical: { border: "border-danger/40", bg: "bg-danger-soft", mark: "text-danger", glyph: "\u2715" },
    warning: { border: "border-warning/40", bg: "bg-warning-soft", mark: "text-warning", glyph: "\u25B3" },
    info: { border: "border-border", bg: "bg-blue-soft", mark: "text-primary", glyph: "\u25CF" }
  }.freeze

  def attention_tone(severity) = ATTENTION_TONES.fetch(severity, ATTENTION_TONES[:info])
end
