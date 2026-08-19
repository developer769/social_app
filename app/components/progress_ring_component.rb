# The progress ring from the analysis screen. Driven by a real percentage
# passed in, never by an animation timer, and it exposes the same number to
# assistive technology as it draws (spec 22, 33).
class ProgressRingComponent < ApplicationComponent
  RADIUS = 52
  STROKE = 8

  def initialize(percentage:, caption: nil, size: 132)
    @percentage = percentage.to_i.clamp(0, 100)
    @caption = caption
    @size = size
  end

  attr_reader :percentage, :caption, :size

  def circumference = (2 * Math::PI * RADIUS).round(2)
  def dash_offset = (circumference * (1 - (percentage / 100.0))).round(2)
  def view_box = "0 0 #{(RADIUS + STROKE) * 2} #{(RADIUS + STROKE) * 2}"
  def centre = RADIUS + STROKE
end
