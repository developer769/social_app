# What one person wants emailed to them about one workspace.
#
# Per person rather than per workspace: two people running the same business
# can reasonably want different things in their inbox.
class NotificationPreference < ApplicationRecord
  include WorkspaceOwned

  CHANNELS = {
    "email_post_published" => [ "A post goes out", "Told each time Prachar publishes something for you." ],
    "email_post_failed" => [ "A post fails", "Told immediately if something could not be published." ],
    "email_post_reminder" => [ "Time to post", "When Prachar cannot publish somewhere itself, a nudge at the scheduled moment with the caption ready." ],
    "email_weekly_summary" => [ "Weekly summary", "A short digest of what went out and how it did." ],
    "email_team_activity" => [ "Team activity", "When someone joins, leaves, or schedules a post." ],
    "email_product_news" => [ "Product news", "Occasional news about new Prachar features." ]
  }.freeze

  belongs_to :user

  validates :user_id, uniqueness: { scope: :workspace_id }

  def self.for(workspace:, user:)
    find_or_create_by!(workspace: workspace, user: user)
  end

  def enabled_channels = CHANNELS.keys.select { |key| public_send(key) }

  # Who in this workspace has asked to hear about something.
  #
  # People with no preference row yet count as opted in to whatever defaults to
  # true, because the alternative is silence for everyone who has never opened
  # the notifications page -- which is most people.
  def self.recipients_for(workspace, channel)
    column = "email_post_#{channel}"
    raise ArgumentError, "unknown channel: #{channel}" unless CHANNELS.key?(column)

    users = workspace.members.merge(WorkspaceMembership.accepted.active).distinct
    preferences = where(workspace: workspace).index_by(&:user_id)
    default_on = columns_hash[column].default == "true"

    users.select do |user|
      preference = preferences[user.id]
      preference ? preference.public_send(column) : default_on
    end
  end
end
