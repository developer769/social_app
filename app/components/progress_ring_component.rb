# The progress ring from the analysis screen. Driven by a real percentage
# passed in, never by an animation timer, and it exposes the same number to
# assistive technology as it draws (spec 22, 33).
class ProgressRingComponent < ApplicationComponent
  RADIUS = 52
  STROKE = 8

  # The spoken label names what is being counted. It was fixed as "checks",
  # which is right on the brand-check screen and wrong everywhere else the ring
  # was later reused.
  def initialize(percentage:, caption: nil, size: 132, counting: "checks")
    @percentage = percentage.to_i.clamp(0, 100)
    @caption = caption
    @size = size
    @counting = counting
  end

  def aria_label = "#{percentage} percent of #{@counting} finished"

  attr_reader :percentage, :caption, :size

  def circumference = (2 * Math::PI * RADIUS).round(2)
  def dash_offset = (circumference * (1 - (percentage / 100.0))).round(2)
  def view_box = "0 0 #{(RADIUS + STROKE) * 2} #{(RADIUS + STROKE) * 2}"
  def centre = RADIUS + STROKE
end
