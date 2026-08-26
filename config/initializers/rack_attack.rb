# Rate limits.
#
# The gem was in the Gemfile and configured nowhere, so failed sign-ins were
# recorded and never slowed down: an attacker could guess as fast as the server
# would answer. Recording an attack is not the same as stopping one.
#
# Limits are deliberately generous. A shop owner mistyping a password on a
# phone must never be locked out; the point is to make guessing expensive, not
# to police honest mistakes.
class Rack::Attack
  # Signing in, by address. Counts only failures, so somebody signing in
  # correctly all day is never touched.
  throttle("logins/ip", limit: 20, period: 5.minutes) do |req|
    req.ip if req.post? && req.path == "/login"
  end

  # And by account, so a spread of addresses cannot be used to hammer one
  # person. Keyed on a digest -- the address itself is never used as a cache
  # key (spec 32).
  throttle("logins/email", limit: 10, period: 20.minutes) do |req|
    next unless req.post? && req.path == "/login"

    email = req.params["email"].to_s.strip.downcase
    OpenSSL::Digest::SHA256.hexdigest(email) if email.present?
  end

  # Reset requests, so the form cannot be used to fill somebody's inbox. The
  # model caps this per account too; this stops the traffic before it reaches
  # the database.
  throttle("password_resets/ip", limit: 10, period: 30.minutes) do |req|
    req.ip if req.post? && req.path == "/password"
  end

  # Staff sign-in is held tighter: there are a handful of these accounts and
  # they reach every workspace.
  throttle("admin_logins/ip", limit: 10, period: 15.minutes) do |req|
    req.ip if req.post? && req.path == "/admin/login"
  end

  # Says when to try again rather than only refusing, and stays vague about
  # why: "you have made 21 attempts" is a useful answer to somebody guessing.
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period].to_i

    [ 429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      [ "Too many attempts. Please wait a few minutes and try again.\n" ] ]
  end

  # Health checks and asset requests must never be counted or blocked.
  safelist("internal") do |req|
    req.path == "/up" || req.path.start_with?("/assets", "/rails/active_storage")
  end
end

# Every block is worth knowing about: a real customer hitting a limit is a bug
# in the limit, and an attacker hitting one is worth seeing.
ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  request = payload[:request]
  Rails.logger.warn(message: "rate limit reached",
                    rule: request.env["rack.attack.matched"],
                    ip: request.ip, path: request.path)
end
