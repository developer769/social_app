# The Settings hub.
#
# An entry is only linked when the thing it manages actually exists. The rest
# are shown with what they are waiting on, rather than as links that go nowhere
# -- the sidebar already made that mistake once.
module SettingsMenu
  Entry = Struct.new(:key, :title, :summary, :route, :tone, :waiting_on, keyword_init: true) do
    def available? = route.present?
  end

  ENTRIES = [
    Entry.new(key: :business, title: "Business profile",
      summary: "Your business details, contact information and description.",
      route: :workspace_settings_business_path, tone: :gold),

    Entry.new(key: :catalog, title: "Products & services",
      summary: "What you sell. Prachar writes content around these.",
      route: :workspace_settings_catalog_path, tone: :blue),

    Entry.new(key: :connections, title: "Social accounts",
      summary: "Connect and manage the accounts Prachar publishes to.",
      route: :workspace_settings_connections_path, tone: :gold),

    Entry.new(key: :team, title: "Team",
      summary: "Invite people to help run this workspace.",
      route: :workspace_settings_team_index_path, tone: :blue),

    Entry.new(key: :security, title: "Security",
      summary: "Your password and the devices signed in to your account.",
      route: :workspace_settings_security_path, tone: :gold),

    Entry.new(key: :billing, title: "Plan & billing",
      summary: "Your plan, what it includes and how much you have used.",
      route: :workspace_settings_billing_path, tone: :blue),

    Entry.new(key: :posting, title: "Posting preferences",
      summary: "How your captions should sound and how often you want to post.",
      route: :workspace_settings_posting_preferences_path, tone: :lavender),

    Entry.new(key: :brand_kit, title: "Brand kit",
      summary: "Your logo, colours and typography, for whoever makes your creatives.",
      route: :workspace_settings_brand_kit_path, tone: :blue),

    Entry.new(key: :notifications, title: "Notifications",
      summary: "Choose what Prachar emails you. Your choices, not the workspace's.",
      route: :workspace_settings_notifications_path, tone: :gold),

    Entry.new(key: :integrations, title: "Integrations",
      summary: "Connect other tools to Prachar.",
      route: nil, tone: :lavender,
      waiting_on: "Social accounts are the only integration today, and they have their own page above."),

    # Publishing defaults live with posting preferences rather than on their own
    # page, because splitting "how it sounds" from "how it goes out" would mean
    # editing two screens to change one thing. Approvals are absent because they
    # need team roles, which are deliberately undefined (spec 2).
    Entry.new(key: :publishing, title: "Publishing defaults",
      summary: "First comment, links and hashtag placement for new posts.",
      route: :workspace_settings_posting_preferences_path, tone: :blue)
  ].freeze

  module_function

  def entries = ENTRIES

  def path_for(entry, workspace)
    return nil unless entry.available?

    Rails.application.routes.url_helpers.public_send(entry.route, workspace_slug: workspace.slug)
  end
end
