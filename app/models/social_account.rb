class SocialAccount < ApplicationRecord
  include WorkspaceOwned

  CONNECTION_STATUSES = %w[connected disconnected expired revoked error].freeze
  PERMISSION_STATUSES = %w[granted partial denied].freeze

  has_one :social_credential, dependent: :destroy
  belongs_to :connected_by, class_name: "User", optional: true

  enum :connection_status, CONNECTION_STATUSES.index_by(&:itself), prefix: :connection, validate: true
  enum :permission_status, PERMISSION_STATUSES.index_by(&:itself), prefix: :permission, validate: true

  scope :connected, -> { where(connection_status: "connected") }
  scope :for_provider, ->(provider) { where(provider: provider) }

  validates :provider, presence: true, inclusion: { in: SocialProvider::Catalog::KEYS }
  validates :external_account_id, presence: true

  def definition = SocialProvider::Catalog.find(provider)
  def capabilities = definition&.capabilities
  def provider_name = definition&.name || provider.humanize

  def handle
    return if username.blank?

    "#{definition&.handle_prefix}#{username}"
  end

  # Explicit transitions rather than assigning to the status attribute (spec 10).
  def mark_connected!(profile:, connected_by: nil)
    update!(
      external_account_id: profile.external_account_id,
      username: profile.username,
      display_name: profile.display_name,
      avatar_url: profile.avatar_url,
      granted_scopes: profile.granted_scopes,
      missing_scopes: expected_scopes - profile.granted_scopes,
      permission_status: (expected_scopes - profile.granted_scopes).empty? ? "granted" : "partial",
      connection_status: "connected",
      token_expires_at: profile.token_expires_at,
      connected_by: connected_by || self.connected_by,
      connected_at: connected_at || Time.current,
      disconnected_at: nil
    )
  end

  def mark_disconnected!
    update!(connection_status: "disconnected", disconnected_at: Time.current)
  end

  def mark_expired!
    update!(connection_status: "expired")
  end

  def expected_scopes
    capabilities ? capabilities.supported.map(&:to_s) : []
  end

  # Publishing must stop before the token dies, not when it dies, so the owner
  # gets a chance to reconnect first.
  def token_expiring_soon?(within: 7.days)
    token_expires_at.present? && token_expires_at <= within.from_now
  end

  def token_expired?
    token_expires_at.present? && token_expires_at <= Time.current
  end

  def usable_for_publishing?
    connection_connected? && !permission_denied? && !token_expired?
  end

  def mocked? = SocialProvider::Registry.mocked?(provider)
end
