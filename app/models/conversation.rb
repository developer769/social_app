# One thread with one person on one platform.
class Conversation < ApplicationRecord
  include WorkspaceOwned

  KINDS = %w[comment direct_message review].freeze
  STATUSES = %w[open closed].freeze

  # What each kind is called on screen. A review is not a message and calling
  # it one would misdescribe what the owner is looking at.
  KIND_LABELS = {
    "comment" => "Comment",
    "direct_message" => "Message",
    "review" => "Review"
  }.freeze

  belongs_to :social_account
  belongs_to :post, optional: true
  belongs_to :closed_by, class_name: "User", optional: true

  has_many :messages, -> { order(:sent_at, :id) }, dependent: :destroy, inverse_of: :conversation

  enum :kind, KINDS.index_by(&:itself), prefix: :kind, validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :external_id, presence: true, uniqueness: { scope: :social_account_id }
  validates :provider, inclusion: { in: SocialProvider::Catalog::KEYS }

  scope :newest_first, -> { order(last_message_at: :desc, id: :desc) }
  scope :of_kind, ->(kind) { where(kind: kind) if kind.present? }
  scope :for_provider, ->(provider) { where(provider: provider) if provider.present? }

  def kind_label = KIND_LABELS.fetch(kind, kind.humanize)
  def provider_name = social_account&.provider_name || provider.humanize

  def participant_label
    participant_name.presence || participant_handle.presence || "Someone"
  end

  # Waiting on the business, rather than on the customer. The distinction is
  # the only thing that makes an inbox a queue rather than a list.
  def awaiting_reply?
    return false if closed?
    return false if last_inbound_at.blank?

    last_outbound = messages.select(&:outbound?).filter_map(&:sent_at).max
    last_outbound.blank? || last_outbound < last_inbound_at
  end

  # Whether Prachar could reply here at all, which depends on the platform and
  # not on the conversation (spec 30).
  def repliable?
    capability = kind_direct_message? ? :direct_messages : :reply_comments
    social_account&.capabilities&.supports?(capability).present?
  end

  def close!(actor:)
    update!(status: "closed", closed_at: Time.current, closed_by: actor)
  end

  def reopen!
    update!(status: "open", closed_at: nil, closed_by: nil)
  end
end
