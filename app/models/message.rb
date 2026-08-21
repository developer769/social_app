class Message < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  DELIVERY_STATUSES = %w[pending sending sent failed].freeze

  belongs_to :conversation
  belongs_to :sent_by, class_name: "User", optional: true

  enum :direction, DIRECTIONS.index_by(&:itself), validate: true
  enum :delivery_status, DELIVERY_STATUSES.index_by(&:itself), prefix: :delivery,
                         validate: { allow_nil: true }

  validates :body, presence: true, length: { maximum: 5_000 }

  def author_label
    return "You" if outbound?

    author_name.presence || conversation.participant_label
  end

  def delivered? = inbound? || delivery_sent?
  def failed? = outbound? && delivery_failed?

  def mark_sent!(external_id: nil)
    update!(delivery_status: "sent", external_id: external_id, sent_at: sent_at || Time.current,
            error_message: nil)
  end

  def mark_failed!(message:)
    update!(delivery_status: "failed", error_message: message.to_s.truncate(200))
  end
end
