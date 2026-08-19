module Posts
  class PostDto < ApplicationDto
    attribute :caption, :hashtags, :call_to_action, :first_comment, :link_url,
              :location_name, :status, :scheduled_at, :scheduled_timezone,
              :social_account_ids, :media_file, :media_kind

    def initialize(caption: nil, hashtags: nil, call_to_action: nil, first_comment: nil,
                   link_url: nil, location_name: nil, status: "draft",
                   scheduled_date: nil, scheduled_time: nil, timezone: nil,
                   social_account_ids: [], media_file: nil)
      @caption = caption.to_s.strip.presence
      @hashtags = normalise_hashtags(hashtags)
      @call_to_action = call_to_action.to_s.strip.presence
      @first_comment = first_comment.to_s.strip.presence
      @link_url = CatalogUrl.normalise(link_url)
      @location_name = location_name.to_s.strip.presence
      @scheduled_timezone = timezone.presence
      @scheduled_at = combine(scheduled_date, scheduled_time, @scheduled_timezone)
      @status = resolve_status(status)
      @social_account_ids = Array(social_account_ids).map(&:to_s).compact_blank
      @media_file = media_file
      @media_kind = media_file&.content_type.to_s.start_with?("video/") ? "video" : "image"
      freeze
    end

    def to_attributes
      {
        caption: caption, hashtags: hashtags, call_to_action: call_to_action,
        first_comment: first_comment, link_url: link_url, location_name: location_name,
        status: status, scheduled_at: scheduled_at, scheduled_timezone: scheduled_timezone
      }
    end

    private

    # Owners type "#cake, sale" or "#cake #sale"; both mean the same thing.
    def normalise_hashtags(value)
      list = value.is_a?(Array) ? value : value.to_s.split(/[\s,]+/)
      list.map { |tag| tag.to_s.strip.delete_prefix("#") }.compact_blank.uniq.first(30)
    end

    def combine(date, time, zone)
      return if date.blank?

      zone_object = ActiveSupport::TimeZone[zone.to_s] || Time.zone
      zone_object.parse("#{date} #{time.presence || '09:00'}")
    rescue ArgumentError
      nil
    end

    # Scheduling without a time is a draft, not a scheduled post with no slot.
    def resolve_status(requested)
      return "scheduled" if requested.to_s == "scheduled" && @scheduled_at.present?

      "draft"
    end
  end
end
