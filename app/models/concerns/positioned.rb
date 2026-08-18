# Shared ordering for catalog items the owner can reorder.
module Positioned
  extend ActiveSupport::Concern

  included do
    scope :in_display_order, -> { order(:position, :id) }

    before_validation :assign_next_position, on: :create
  end

  private

  def assign_next_position
    return if position.present? && !position.zero?

    self.position = self.class.for_workspace(workspace).maximum(:position).to_i + 1
  end
end
