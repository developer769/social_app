# The "Why this matters" rail from the onboarding screens. Sits beside the form
# on desktop and below it on smaller screens (spec 19).
class ContextualHelpPanelComponent < ApplicationComponent
  renders_many :points, "PointComponent"

  def initialize(title:, summary: nil, tone: :blue)
    @title = title
    @summary = summary
    @tone = tone
  end

  attr_reader :title, :summary, :tone

  def panel_classes
    background = { blue: "bg-blue-soft", lavender: "bg-lavender-soft", gold: "bg-gold-tint" }.fetch(tone, "bg-blue-soft")
    "rounded-card border border-border #{background} p-6"
  end

  class PointComponent < ApplicationComponent
    def initialize(title:, body: nil)
      @title = title
      @body = body
    end

    attr_reader :title, :body

    def call
      tag.li(class: "flex gap-3") do
        safe_join([
          tag.span(class: "mt-0.5 h-8 w-8 shrink-0 rounded-full bg-surface", aria: { hidden: true }),
          tag.span do
            safe_join([
              tag.span(title, class: "block text-sm font-medium text-heading"),
              (body.present? ? tag.span(body, class: "mt-0.5 block text-xs text-body") : nil)
            ].compact)
          end
        ])
      end
    end
  end
end
