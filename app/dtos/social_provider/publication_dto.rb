module SocialProvider
  # What came back from a successful publish. The remote id is what makes the
  # post findable again for analytics and for comments later, so it is required
  # rather than optional.
  class PublicationDto < ApplicationDto
    attribute :remote_post_id, :permalink, :published_at, :raw

    def initialize(remote_post_id:, permalink: nil, published_at: nil, raw: {})
      @remote_post_id = remote_post_id.to_s
      @permalink = permalink
      @published_at = published_at
      @raw = raw.freeze
      freeze
    end
  end
end
