module SocialProvider
  # Carries tokens between the adapter and storage. Never logged, never
  # serialised into a job payload (spec 32).
  class CredentialsDto < ApplicationDto
    attribute :access_token, :refresh_token, :expires_at

    def initialize(access_token:, refresh_token: nil, expires_at: nil)
      @access_token = access_token
      @refresh_token = refresh_token
      @expires_at = expires_at
      freeze
    end

    # Guards against a token reaching the log through an accidental interpolation.
    def inspect = "#<SocialProvider::CredentialsDto [FILTERED]>"
    def to_s = inspect
  end
end
