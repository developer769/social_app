module SocialProvider
  # The normalised shape every adapter returns, so no provider's field names
  # leak into the rest of the application (spec 11, 30).
  class ProfileDto < ApplicationDto
    attribute :provider, :external_account_id, :username, :display_name,
              :avatar_url, :granted_scopes, :token_expires_at

    def initialize(provider:, external_account_id:, username: nil, display_name: nil,
                   avatar_url: nil, granted_scopes: [], token_expires_at: nil)
      @provider = provider.to_s
      @external_account_id = external_account_id.to_s
      @username = username
      @display_name = display_name
      @avatar_url = avatar_url
      @granted_scopes = Array(granted_scopes).map(&:to_s).freeze
      @token_expires_at = token_expires_at
      freeze
    end
  end
end
