class SocialCredential < ApplicationRecord
  belongs_to :social_account

  encrypts :access_token
  encrypts :refresh_token

  # Tokens must never appear in logs, exception reports or job payloads.
  def inspect = "#<SocialCredential id: #{id.inspect}, social_account_id: #{social_account_id.inspect} [FILTERED]>"

  def expired? = expires_at.present? && expires_at <= Time.current
end
