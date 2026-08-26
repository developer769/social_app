module PostsHelper
  # What an empty list means depends on which group you are looking at, and
  # "no posts" would be wrong in three of the four cases.
  EMPTY_TITLES = {
    "needs_you" => [ "Nothing needs you", "Every post is either scheduled or done." ],
    "in_flight" => [ "Nothing is coming up", "Schedule a post and it will appear here." ],
    "settled" => [ "Nothing has gone out yet", "Posts that have been published or reminded about will be kept here." ],
    "all" => [ "No posts yet", "Start one from a style, or upload your own picture." ]
  }.freeze

  def empty_title_for(group) = EMPTY_TITLES.fetch(group, EMPTY_TITLES["all"]).first
  def empty_body_for(group) = EMPTY_TITLES.fetch(group, EMPTY_TITLES["all"]).last

  # How one platform's copy of a post reads on the status screen.
  #
  # "Skipped" deliberately does not use the danger tone: nothing went wrong when
  # Prachar cannot reach a platform yet, and colouring it like a failure would
  # tell the owner their post is broken when it is not.
  TARGET_BADGES = {
    "pending" => [ "Waiting", :neutral ],
    "validating" => [ "Checking", :neutral ],
    "publishing" => [ "Posting", :warning ],
    "published" => [ "Posted", :success ],
    "failed" => [ "Did not post", :danger ],
    "skipped" => [ "Not posted", :info ]
  }.freeze

  def target_badge(target)
    label, tone = TARGET_BADGES.fetch(target.status, [ target.status.humanize, :neutral ])
    { label: label, tone: tone }
  end

  # Why an account cannot carry this post, or nil when it can. Read from real
  # provider capabilities rather than assumed, so the form never offers a
  # destination the API would refuse (spec 30).
  def account_block_reason(account, post)
    capabilities = account.capabilities
    return "This platform's capabilities are unknown." if capabilities.nil?

    asset = post.post_media.first&.media_asset
    return nil if asset.nil?

    if asset.video? && !capabilities.publish_video?
      "#{account.provider_name} cannot post video."
    elsif asset.image? && !capabilities.publish_image?
      "#{account.provider_name} only accepts video."
    end
  end

  # The binding limit is the smallest across the chosen platforms, and it names
  # which one, so a caption cut to 280 characters is explained by X rather than
  # appearing arbitrary.
  def caption_limit_hint(accounts, selected_ids)
    chosen = accounts.select { |account| selected_ids.include?(account.id) }
    return "Choose where this goes and the length limit will appear here." if chosen.empty?

    binding_account = chosen.min_by { |account| account.capabilities&.max_caption_length || Float::INFINITY }
    limit = binding_account.capabilities&.max_caption_length
    return "No caption limit on the platforms you chose." if limit.nil?

    "Up to #{number_with_delimiter(limit)} characters, the limit on #{binding_account.provider_name}."
  end

  def hashtag_limit_hint(accounts, selected_ids)
    chosen = accounts.select { |account| selected_ids.include?(account.id) }
    limits = chosen.filter_map { |account| account.capabilities&.max_hashtags }

    # Only Instagram publishes a hashtag cap, so with no Instagram target there
    # is no denominator to show and inventing one would be wrong.
    return "Separate them with spaces." if limits.empty?

    "Up to #{limits.min} hashtags, the limit on the platforms you chose."
  end
end
