module SocialProvider
  # The seven providers and what each can genuinely do.
  #
  # IMPORTANT: these limits reflect published platform behaviour at the time of
  # writing and MUST be re-verified against the provider's live documentation
  # before that provider's real adapter ships (spec 35, phase 6). They are
  # deliberately conservative: claiming less than a platform offers is
  # recoverable, claiming more breaks a customer's post.
  module Catalog
    Definition = Struct.new(:key, :name, :handle_prefix, :capabilities, :notes, :ad_metrics,
                            keyword_init: true) do
      # What this platform reports back about an ad. Deliberately different per
      # platform: Meta reports reach, LinkedIn and X do not, and a dashboard
      # that showed every column for every platform would have to invent the
      # missing ones or print a zero that reads as "nobody saw it".
      def reports?(metric) = ad_metrics.include?(metric.to_sym)
    end

    def self.define(key, name, handle_prefix:, supports:, limits:, notes:, ad_metrics: [])
      Definition.new(
        key: key, name: name, handle_prefix: handle_prefix,
        capabilities: Capabilities.new(supports: supports, limits: limits),
        notes: notes, ad_metrics: ad_metrics.map(&:to_sym).freeze
      )
    end

    # Every figure an ad platform can report, in the order a shop owner reads
    # them: what it cost, then how far it went, then what it did.
    AD_METRICS = {
      spend: "Spent",
      impressions: "Times shown",
      reach: "People reached",
      clicks: "Clicks",
      results: "Results"
    }.freeze

    # Purchase counts and their value are listed separately because they are
    # not like the others: a platform CAN report them, but only when a tracking
    # tag on a website is telling it about purchases. A shop taking orders on
    # WhatsApp will get nothing here no matter which platform it uses, and that
    # is a fact about the shop rather than about the platform.
    REVENUE_METRICS = %i[conversions conversion_value].freeze

    ALL = {
      "instagram" => define("instagram", "Instagram", handle_prefix: "@",
        supports: %i[publish_image publish_video publish_carousel publish_story first_comment
                     read_comments reply_comments direct_messages analytics advertising],
        limits: { max_caption_length: 2_200, max_hashtags: 30, max_media_count: 10,
                  max_video_seconds: 90, daily_publish_limit: 25 },
        ad_metrics: %i[spend impressions reach clicks results conversions conversion_value],
        notes: "Requires a Professional account linked to a Facebook Page. Publishing is capped per rolling 24 hours."),

      "facebook" => define("facebook", "Facebook Page", handle_prefix: "",
        supports: %i[publish_image publish_video publish_carousel publish_text first_comment
                     read_comments reply_comments direct_messages analytics advertising],
        limits: { max_caption_length: 63_206, max_media_count: 10, max_video_seconds: 14_400 },
        ad_metrics: %i[spend impressions reach clicks results conversions conversion_value],
        notes: "Uses Page access tokens, which expire and must be refreshed."),

      "linkedin" => define("linkedin", "LinkedIn", handle_prefix: "",
        supports: %i[publish_image publish_video publish_text read_comments reply_comments
                     analytics advertising],
        limits: { max_caption_length: 3_000, max_media_count: 9, max_video_seconds: 600 },
        ad_metrics: %i[spend impressions clicks conversions conversion_value],
        notes: "Posting needs Community Management API approval. No page-level direct messages."),

      "youtube" => define("youtube", "YouTube", handle_prefix: "@",
        supports: %i[publish_video read_comments reply_comments analytics],
        limits: { max_caption_length: 5_000, max_media_count: 1, max_video_seconds: 43_200,
                  daily_publish_limit: 6 },
        notes: "Quota-bound: one upload consumes a large share of the default daily allowance, so only a handful of videos per day are possible. Cannot post images."),

      "tiktok" => define("tiktok", "TikTok", handle_prefix: "@",
        supports: %i[publish_video analytics],
        limits: { max_caption_length: 2_200, max_media_count: 1, max_video_seconds: 600 },
        notes: "Content Posting API requires app audit. Unaudited apps can only post privately."),

      "google_business" => define("google_business", "Google Business Profile", handle_prefix: "",
        supports: %i[publish_image publish_text reviews read_comments reply_comments analytics],
        limits: { max_caption_length: 1_500, max_media_count: 1 },
        notes: "Requires a verified business. Post types are constrained and quota-limited."),

      "x" => define("x", "X", handle_prefix: "@",
        supports: %i[publish_image publish_video publish_text direct_messages analytics advertising],
        limits: { max_caption_length: 280, max_media_count: 4, max_video_seconds: 140 },
        ad_metrics: %i[spend impressions clicks conversions conversion_value],
        notes: "Paid API tiers only, with low posting volume at the entry level.")
    }.freeze

    KEYS = ALL.keys.freeze

    module_function

    def all = ALL.values
    def find(key) = ALL[key.to_s]
    def keys = KEYS
    def capabilities_for(key) = find(key)&.capabilities
  end
end
