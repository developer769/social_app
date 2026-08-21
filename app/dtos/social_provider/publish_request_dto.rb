module SocialProvider
  # What a provider is asked to publish, in one shape, so no platform's field
  # names leak into the rest of the application (spec 11, 30).
  class PublishRequestDto < ApplicationDto
    attribute :caption, :hashtags, :media, :link_url, :first_comment,
              :location_name, :idempotency_key, :scheduled_at

    def initialize(caption: nil, hashtags: [], media: [], link_url: nil, first_comment: nil,
                   location_name: nil, idempotency_key:, scheduled_at: nil)
      @caption = caption.to_s
      @hashtags = Array(hashtags).map(&:to_s).freeze
      @media = Array(media).freeze
      @link_url = link_url
      @first_comment = first_comment
      @location_name = location_name
      # Carried to the provider so a retry of the same work cannot publish
      # twice. Every adapter must pass it through.
      @idempotency_key = idempotency_key
      @scheduled_at = scheduled_at
      freeze
    end

    def media? = @media.any?
    def video? = @media.first&.video?
  end
end
