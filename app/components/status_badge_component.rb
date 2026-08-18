# Status is never conveyed by colour alone: each tone carries its own glyph as
# well, so the badge still reads for colour-blind users and in monochrome
# (spec 33).
class StatusBadgeComponent < ApplicationComponent
  TONES = {
    neutral:   { classes: "bg-surface-sunk text-body border-border",                glyph: "\u25CB" },
    highlight: { classes: "bg-gold-tint text-heading border-gold-soft",             glyph: "\u2605" },
    success:   { classes: "bg-success-soft text-success border-success/30",         glyph: "\u2713" },
    warning:   { classes: "bg-warning-soft text-warning border-warning/30",         glyph: "\u25B3" },
    danger:    { classes: "bg-danger-soft text-danger border-danger/30",            glyph: "\u2715" },
    info:      { classes: "bg-blue-soft text-primary border-border",                glyph: "\u25CF" }
  }.freeze

  def initialize(label:, tone: :neutral)
    @label = label
    @tone = TONES.key?(tone) ? tone : :neutral
  end

  attr_reader :label, :tone

  def classes = TONES.fetch(tone)[:classes]
  def glyph = TONES.fetch(tone)[:glyph]

  def call
    tag.span(class: "inline-flex items-center gap-1.5 rounded-pill border px-2.5 py-1 text-xs font-medium #{classes}") do
      safe_join([ tag.span(glyph, aria: { hidden: true }), label ])
    end
  end
end
