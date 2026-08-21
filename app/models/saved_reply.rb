# An answer written once and used often.
#
# Useful before any inbox connects: while Prachar cannot reply for you, it can
# hold the answer you always give about delivery areas or opening hours, ready
# to copy into the platform's own app.
class SavedReply < ApplicationRecord
  include WorkspaceOwned

  belongs_to :created_by, class_name: "User", optional: true

  validates :title, presence: true, length: { maximum: 80 },
                    uniqueness: { scope: :workspace_id, case_sensitive: false }
  validates :body, presence: true, length: { maximum: 2_000 }

  scope :in_display_order, -> { order(:position, :id) }
  scope :most_used, -> { order(times_used: :desc, position: :asc) }

  def record_use!
    # Counted without validation or callbacks: using a reply is not editing it,
    # and a title that has since become invalid must not block the count.
    self.class.where(id: id).update_all("times_used = times_used + 1")
  end
end
