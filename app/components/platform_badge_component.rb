# The platform mark. Each provider keeps one appearance everywhere it appears,
# and the accessible name is the platform's own name, not a colour or a letter.
class PlatformBadgeComponent < ApplicationComponent
  SIZES = { small: "h-6 w-6 text-[0.6rem]", medium: "h-8 w-8 text-xs", large: "h-10 w-10 text-sm" }.freeze

  INITIALS = {
    "instagram" => "IG", "facebook" => "FB", "linkedin" => "in",
    "youtube" => "YT", "tiktok" => "TT", "google_business" => "GB", "x" => "X"
  }.freeze

  def initialize(provider:, size: :medium)
    @provider = provider.to_s
    @size = SIZES.key?(size) ? size : :medium
  end

  attr_reader :provider, :size

  def definition = SocialProvider::Catalog.find(provider)
  def name = definition&.name || provider.humanize
  def initials = INITIALS.fetch(provider, provider.first(2).upcase)
  def size_classes = SIZES.fetch(size)

  def call
    tag.span(
      class: "inline-flex shrink-0 items-center justify-center rounded-control " \
             "border border-border bg-surface-sunk font-semibold text-heading #{size_classes}",
      title: name
    ) do
      safe_join([ tag.span(initials, aria: { hidden: true }), tag.span(name, class: "sr-only") ])
    end
  end
end
