# The platform's own mark, in its own colour.
#
# The initials badge was fine for a settings list but reads as placeholder on a
# calendar, where a shop owner scans by shape and colour rather than by reading.
# Each mark is drawn inline so it needs no external request, and every one
# carries the platform name for assistive technology.
class PlatformGlyphComponent < ApplicationComponent
  SIZES = { small: "h-5 w-5", medium: "h-6 w-6", large: "h-9 w-9" }.freeze

  BRANDS = {
    "instagram" => { colour: "#E1306C", tint: "#FDEEF3" },
    "facebook" => { colour: "#1877F2", tint: "#EAF2FD" },
    "linkedin" => { colour: "#0A66C2", tint: "#EAF2FD" },
    "youtube" => { colour: "#FF0000", tint: "#FDEDED" },
    "tiktok" => { colour: "#111111", tint: "#F5F1EA" },
    "google_business" => { colour: "#1E8E3E", tint: "#EDF6EF" },
    "x" => { colour: "#0F1419", tint: "#F2F2F3" }
  }.freeze

  FALLBACK = { colour: "#485064", tint: "#F6F0E7" }.freeze

  def initialize(provider:, size: :medium)
    @provider = provider.to_s
    @size = SIZES.key?(size) ? size : :medium
  end

  attr_reader :provider, :size

  def name = SocialProvider::Catalog.find(provider)&.name || provider.humanize
  def colour = BRANDS.fetch(provider, FALLBACK)[:colour]
  def tint = BRANDS.fetch(provider, FALLBACK)[:tint]
  def size_classes = SIZES.fetch(size)

  # Simplified marks: recognisable at 20px, and drawn rather than fetched.
  def path
    case provider
    when "instagram"
      %(<rect x="3" y="3" width="18" height="18" rx="5.5" fill="none" stroke="currentColor" stroke-width="1.8"/>
        <circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="1.8"/>
        <circle cx="17.2" cy="6.8" r="1.2" fill="currentColor"/>)
    when "facebook"
      %(<path fill="currentColor" d="M13.5 21v-8h2.7l.4-3h-3.1V8.1c0-.9.3-1.5 1.5-1.5h1.7V3.9c-.3 0-1.3-.1-2.4-.1-2.4 0-4 1.5-4 4.1V10H7.5v3h2.8v8z"/>)
    when "linkedin"
      %(<rect x="3" y="3" width="18" height="18" rx="3" fill="none" stroke="currentColor" stroke-width="1.8"/>
        <path fill="currentColor" d="M7.6 10.2h1.9V17H7.6zm.95-3a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 0 1 0-2.2zM11.4 10.2h1.8v.9c.4-.6 1.1-1.1 2.1-1.1 1.6 0 2.4 1 2.4 2.9V17h-1.9v-3.7c0-1-.4-1.5-1.2-1.5s-1.3.5-1.3 1.5V17h-1.9z"/>)
    when "youtube"
      %(<rect x="2.5" y="6" width="19" height="12" rx="3.5" fill="currentColor"/>
        <path fill="#fff" d="M10.4 9.4v5.2l4.4-2.6z"/>)
    when "tiktok"
      %(<path fill="currentColor" d="M14.1 3h2.4c.2 1.6 1.2 2.9 2.8 3.2v2.4c-1.1 0-2.1-.3-3-.9v5.6a5 5 0 1 1-5-5c.2 0 .4 0 .6.03v2.5a2.6 2.6 0 1 0 1.9 2.5z"/>)
    when "google_business"
      %(<path fill="currentColor" d="M12 3a9 9 0 1 0 8.8 10.9h-8.5v-3h11.4c.1.6.1 1.2.1 1.8 0 5.6-3.9 9.6-9.8 9.6A9.9 9.9 0 1 1 12 2.1a9.5 9.5 0 0 1 6.6 2.6L16.5 6.8A6.4 6.4 0 0 0 12 5z"/>)
    when "x"
      %(<path fill="currentColor" d="M17.3 3h3.1l-6.8 7.8L21.6 21h-6.2l-4.9-6.4L4.8 21H1.7l7.3-8.3L1.6 3h6.4l4.4 5.8zm-1.1 16.1h1.7L7.9 4.8H6z"/>)
    else
      %(<circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="1.8"/>)
    end
  end
end
