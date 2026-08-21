# Turns an audit row into a sentence a shop owner can read.
#
# Every one of these events was already being recorded and none of them were
# visible to the people they were about, which made the trail useful only to
# staff. This is the customer's own view of it.
class ActivityPresenter
  # An allowlist, not a humanised fallback. A new audit action is invisible here
  # until somebody writes a phrasing for it, so nobody can add an event
  # tomorrow and have its metadata appear on a customer's screen by accident.
  #
  # Each entry is [tone, phrase]. The phrase never includes the actor's name --
  # the view puts that in front, so "Anaya" + "connected Instagram" reads as one
  # sentence and an unattributed event still makes sense.
  PHRASINGS = {
    "workspace.created" => [ :success, ->(_e) { "created this workspace" } ],
    "subscription.trial_started" => [ :success, ->(_e) { "started the free trial" } ],

    "onboarding.business_setup_saved" => [ :neutral, ->(_e) { "updated the business profile" } ],
    "brand_kit.updated" => [ :neutral, ->(_e) { "updated the brand kit" } ],
    "posting_preferences.updated" => [ :neutral, ->(_e) { "updated posting preferences" } ],

    "social_account.connected" => [ :success, ->(e) { "connected #{e.provider_label}" } ],
    "social_account.disconnected" => [ :danger, ->(e) { "disconnected #{e.provider_label}" } ],

    "workspace_membership.invited" => [ :neutral, ->(e) { "invited #{e.invitee_label}" } ],
    "workspace_membership.accepted" => [ :success, ->(_e) { "joined this workspace" } ],
    "workspace_membership.declined" => [ :neutral, ->(_e) { "declined the invitation" } ],
    "workspace_membership.invitation_cancelled" => [ :neutral, ->(_e) { "cancelled an invitation" } ],
    "workspace_membership.removed" => [ :danger, ->(_e) { "removed someone from this workspace" } ],
    "workspace_membership.left" => [ :neutral, ->(_e) { "left this workspace" } ],

    "post.started_from_template" => [ :neutral, ->(e) { "started a post#{e.template_suffix}" } ],
    "post.cancelled" => [ :danger, ->(_e) { "cancelled a scheduled post" } ],
    "post.deleted" => [ :danger, ->(_e) { "deleted a post" } ],
    "creative.requested" => [ :neutral, ->(e) { "asked for pictures#{e.template_suffix}" } ],

    "brand_analysis.started" => [ :neutral, ->(_e) { "ran a check on the business" } ],
    "social_health.computed" => [ :neutral, ->(_e) { "refreshed the social health score" } ],

    "user.password_changed" => [ :neutral, ->(_e) { "changed their password" } ],
    "user.session_revoked" => [ :neutral, ->(_e) { "signed a device out" } ]
  }.freeze

  # Shown only to the person they are about. Everyone in a workspace has a
  # reason to know a post was deleted; nobody else needs to know when a
  # colleague changed their password.
  PERSONAL = %w[user.password_changed user.session_revoked].freeze

  attr_reader :event

  def initialize(event, viewer:, template_names: {})
    @event = event
    @viewer = viewer
    @template_names = template_names
  end

  def self.visible_for(events, viewer:)
    # Audit rows store a template's slug, because a slug survives a rename and a
    # name does not. Reading them back needs the names, so they are fetched once
    # for the whole page rather than once per line.
    names = template_names_for(events)

    events.map { |event| new(event, viewer: viewer, template_names: names) }.select(&:visible?)
  end

  def self.template_names_for(events)
    slugs = events.filter_map { |event| event.metadata["template"].presence }.uniq
    return {} if slugs.empty?

    ::Template.where(slug: slugs).pluck(:slug, :name).to_h
  end
  private_class_method :template_names_for

  def visible? = PHRASINGS.key?(action) && (!personal? || own?)

  def action = event.action
  def occurred_at = event.created_at
  def tone = PHRASINGS.fetch(action).first
  def sentence = PHRASINGS.fetch(action).last.call(self)

  def actor_name
    return "Someone" if event.actor_user.nil?

    own? ? "You" : event.actor_user.name
  end

  def initials
    actor_name.split.first(2).filter_map { |part| part[0] }.join.upcase.presence || "?"
  end

  # ---- Fragments the phrasings above are allowed to use --------------------
  # Each one falls back to something vague rather than raising, because an
  # audit row is history: the thing it describes may have been deleted since.

  def provider_label
    key = metadata["provider"] || event.auditable.try(:provider)
    return "an account" if key.blank?

    SocialProvider::Catalog::ALL[key.to_s]&.name || key.to_s.titleize
  end

  def invitee_label = metadata["invitation_email"].presence || metadata["email"].presence || "someone"

  def template_suffix
    slug = metadata["template"].presence
    return "" if slug.blank?

    # A style deleted since is still worth naming as best we can, rather than
    # dropping the only detail that made the line meaningful.
    " from #{@template_names.fetch(slug) { slug.tr('-', ' ').titleize }}"
  end

  private

  def metadata = event.metadata.presence || {}
  def personal? = PERSONAL.include?(action)
  def own? = @viewer.present? && event.actor_user_id == @viewer.id
end
