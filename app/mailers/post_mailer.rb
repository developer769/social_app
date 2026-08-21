class PostMailer < ApplicationMailer
  # The scheduled moment has arrived and Prachar cannot reach the platform
  # itself. Everything needed to post it by hand is in the email, because the
  # useful thing here is not the notification -- it is not having to go and find
  # the caption.
  def time_to_post(post, user)
    @post = post
    @user = user
    @workspace = post.workspace
    @caption = full_caption(post)
    @providers = post.post_targets.map(&:provider_name).uniq
    @post_url = workspace_post_url(workspace_slug: @workspace.slug, id: post)

    attach_media(post)

    mail(to: user.email, subject: "Time to post: #{summary(post)}")
  end

  def published(post, user)
    @post = post
    @user = user
    @workspace = post.workspace
    @published = post.post_targets.select(&:published?)
    @unpublished = post.post_targets.reject(&:published?)
    @post_url = workspace_post_url(workspace_slug: @workspace.slug, id: post)

    mail(to: user.email, subject: subject_for_published(post))
  end

  def failed(post, user)
    @post = post
    @user = user
    @workspace = post.workspace
    @failures = post.post_targets.reject(&:published?)
    @post_url = workspace_post_url(workspace_slug: @workspace.slug, id: post)

    mail(to: user.email, subject: "Could not post: #{summary(post)}")
  end

  private

  def summary(post)
    post.caption.presence&.truncate(60) || post.template&.name || "your post"
  end

  def subject_for_published(post)
    return "Posted to #{post.post_targets.select(&:published?).map(&:provider_name).to_sentence}" if post.published?

    "Partly posted: #{summary(post)}"
  end

  def full_caption(post)
    [ post.caption.presence, post.hashtags.map { |tag| "##{tag}" }.join(" ").presence ]
      .compact.join("\n\n")
  end

  # The picture travels with the email so it can be posted straight from a
  # phone, without signing in to find it.
  def attach_media(post)
    asset = post.primary_media
    return unless asset&.file&.attached?
    return if asset.file.byte_size > 8.megabytes

    attachments[asset.file.filename.to_s] = asset.file.download
  rescue StandardError => e
    # An email that arrives without the picture is still worth sending.
    Rails.logger.warn(message: "could not attach media to reminder",
                      post_id: post.id, error: e.class.name)
  end
end
