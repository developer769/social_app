# Turns an email address into something safe to store in an audit trail.
#
# The hint is human-readable enough to recognise your own address in a security
# log; the digest is stable enough to count attempts against one address. The
# address itself is never written down (spec 13: never log sensitive user data).
module EmailHint
  module_function

  def mask(email)
    address = email.to_s.strip.downcase
    local, domain = address.split("@", 2)
    return "(blank)" if local.blank?
    return "#{visible(local)}***" if domain.blank?

    "#{visible(local)}***@#{domain}"
  end

  def digest(email)
    address = email.to_s.strip.downcase
    return if address.blank?

    OpenSSL::Digest::SHA256.hexdigest(address).first(16)
  end

  def visible(local) = local.first(2)
end
