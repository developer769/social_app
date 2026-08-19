module CalendarHelper
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
