module SocialProvider
  # What a provider can ACTUALLY do.
  #
  # The interface reads this rather than assuming every platform behaves like
  # Instagram. If a provider has no direct-message API, the Inbox does not
  # render a direct-message filter for it and then fail -- it does not render
  # one at all (spec 30: never claim unsupported platform capabilities).
  class Capabilities
    FLAGS = %i[
      publish_image publish_video publish_carousel publish_story publish_text
      first_comment read_comments reply_comments direct_messages reviews
      analytics advertising
    ].freeze

    attr_reader :limits

    def initialize(supports: [], limits: {})
      @supports = supports.map(&:to_sym).to_set
      @limits = limits.freeze
      validate_flags!
      freeze
    end

    FLAGS.each do |flag|
      define_method(:"#{flag}?") { @supports.include?(flag) }
    end

    def supports?(flag) = @supports.include?(flag.to_sym)
    def supported = @supports.to_a.sort

    def max_caption_length = limits[:max_caption_length]
    def max_hashtags = limits[:max_hashtags]
    def max_media_count = limits[:max_media_count]
    def max_video_seconds = limits[:max_video_seconds]
    def daily_publish_limit = limits[:daily_publish_limit]

    private

    def validate_flags!
      unknown = @supports - FLAGS.to_set
      raise ArgumentError, "unknown capability flags: #{unknown.to_a.join(', ')}" if unknown.any?
    end
  end
end
