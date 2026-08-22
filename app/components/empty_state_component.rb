# The honest "there is nothing here yet" state (spec 20). Says what is missing
# and what to do about it, rather than showing placeholder data.
class EmptyStateComponent < ApplicationComponent
  renders_one :action

  # The mark is chosen per situation. A picture frame stood on every empty state
  # in the app, including inboxes and calendars, which made the icon decoration
  # rather than information -- and told a reader nothing about what was empty.
  ICONS = {
    media: %(<rect x="4" y="5" width="16" height="14" rx="2" />
             <path d="M4 15l4-4 3 3 3-3 6 6" stroke-linejoin="round" />),
    calendar: %(<rect x="3.5" y="5" width="17" height="15" rx="2" />
                <path d="M3.5 10h17M8 3.5v3M16 3.5v3" stroke-linecap="round" />),
    inbox: %(<path d="M3.5 12.5h4l1.5 2.5h6l1.5-2.5h4" stroke-linejoin="round" />
             <path d="M5 5.5h14l2.5 7v4a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2v-4z" stroke-linejoin="round" />),
    chart: %(<path d="M4 20V10M10 20V4M16 20v-7M22 20H2" stroke-linecap="round" />),
    catalog: %(<rect x="3.5" y="7" width="17" height="13" rx="2" />
               <path d="M8.5 7V5.5a3.5 3.5 0 0 1 7 0V7" stroke-linecap="round" />),
    search: %(<circle cx="11" cy="11" r="6.5" />
              <path d="M16 16l4.5 4.5" stroke-linecap="round" />),
    money: %(<circle cx="12" cy="12" r="8.5" />
             <path d="M9 8.5h6M9 11.5h6M14 8.5c0 3-1.5 4-4 4l4.5 4" stroke-linecap="round" stroke-linejoin="round" />)
  }.freeze

  def initialize(title:, body: nil, icon: :media)
    @title = title
    @body = body
    @icon = ICONS.key?(icon) ? icon : :media
  end

  attr_reader :title, :body, :icon

  def icon_paths = ICONS.fetch(icon).html_safe
end
