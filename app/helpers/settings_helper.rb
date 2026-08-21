module SettingsHelper
  # A readable device name from a user agent string. Deliberately coarse: the
  # point is to recognise your own laptop, not to fingerprint anyone.
  def device_description(user_agent)
    return "Unknown device" if user_agent.blank?

    browser =
      case user_agent
      when /Edg\//i then "Edge"
      when /OPR\/|Opera/i then "Opera"
      when /Chrome/i then "Chrome"
      when /Safari/i then "Safari"
      when /Firefox/i then "Firefox"
      else "Browser"
      end

    platform =
      case user_agent
      when /Windows/i then "Windows"
      when /Macintosh|Mac OS/i then "Mac"
      when /Android/i then "Android"
      when /iPhone|iPad|iOS/i then "iOS"
      when /Linux/i then "Linux"
      else nil
      end

    [ browser, platform ].compact.join(" on ")
  end
end
