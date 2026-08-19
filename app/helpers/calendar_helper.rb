module CalendarHelper
  # "Post", "Reel", "Offer" -- what the design labels each event with. Derived
  # from the template the post came from, falling back to the media type.
  def post_kind_label(post)
    return post.template.category_label if post.template&.content_category == "offer"
    return "Reel" if post.template&.format_video? || post.primary_media&.video?

    "Post"
  end

  def calendar_empty_title(calendar)
    if calendar.provider.present?
      "Nothing scheduled for #{SocialProvider::Catalog.find(calendar.provider)&.name}"
    else
      "Nothing scheduled #{calendar.view == 'agenda' ? 'in the next 30 days' : 'this ' + calendar.view}"
    end
  end

  def calendar_empty_body(calendar)
    if calendar.provider.present?
      "Other platforms may still have posts in this period. Clear the filter to see everything."
    else
      "Pick a style, choose what it should feature, and schedule it. It will appear here."
    end
  end

  # The countdown badge is graded by how soon the post goes out, matching the
  # design: imminent reads green, then blue, then amber further out.
  def countdown_classes(post, workspace)
    return "bg-danger-soft text-danger" if post.scheduled_at.blank?

    zone = ActiveSupport::TimeZone[workspace.timezone] || Time.zone
    days = (post.scheduled_at.in_time_zone(zone).to_date - zone.today).to_i

    case days
    when ..-1 then "bg-danger-soft text-danger"
    when 0..1 then "bg-success-soft text-success"
    when 2..4 then "bg-blue-soft text-primary"
    else "bg-gold-tint text-warning"
    end
  end

  # "Tomorrow", "In 3 days" -- read in the workspace's own timezone, so a post
  # late tonight does not read as tomorrow to someone in another zone.
  def relative_schedule(post, workspace)
    return "" if post.scheduled_at.blank?

    zone = ActiveSupport::TimeZone[workspace.timezone] || Time.zone
    days = (post.scheduled_at.in_time_zone(zone).to_date - zone.today).to_i

    case days
    when ..-1 then "Overdue"
    when 0 then "Today"
    when 1 then "Tomorrow"
    when 2..30 then "In #{days} days"
    else post.scheduled_at.in_time_zone(zone).strftime("%-d %b")
    end
  end
end
