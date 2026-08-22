# The picture for one product or service, or a decent stand-in when there is
# none.
#
# Most workspaces will not have photographed everything they sell, and a blank
# grey square made a finished screen look broken. A tinted tile carrying the
# item's initial is unmistakably a placeholder, reads as deliberate, and never
# pretends to be a photograph.
class CatalogThumbComponent < ApplicationComponent
  SIZES = { small: "h-10 w-10 text-sm", medium: "h-16 w-16 text-lg", large: "h-24 w-24 text-2xl" }.freeze

  # Warm, low-saturation grounds from the workspace palette. Picked from the
  # name so an item keeps the same colour everywhere it appears.
  TINTS = [
    { bg: "#FDF1DC", fg: "#8A6A21" },
    { bg: "#EEEAF7", fg: "#4B3B7A" },
    { bg: "#E8F0F7", fg: "#2C5578" },
    { bg: "#E6F0EA", fg: "#1A7048" },
    { bg: "#F8E7E9", fg: "#8E2A36" }
  ].freeze

  def initialize(item:, size: :medium)
    @item = item
    @size = SIZES.key?(size) ? size : :medium
  end

  attr_reader :item, :size

  def image
    return item.image if item.respond_to?(:image)

    item.cover_image if item.respond_to?(:cover_image)
  end

  def attached? = image&.attached?

  def size_classes = SIZES.fetch(size)

  def initial = item.name.to_s.strip.first&.upcase.presence || "?"

  def tint
    TINTS[item.name.to_s.sum % TINTS.size]
  end
end
