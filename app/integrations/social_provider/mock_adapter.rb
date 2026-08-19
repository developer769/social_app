module SocialProvider
  # Stands in for every provider until real credentials and app review are in
  # place (spec 22, step 3). It is deterministic: the same workspace and
  # provider always produce the same fake account, so development and specs are
  # stable across runs.
  #
  # It is honest about capability: asking it to do something the real provider
  # cannot do raises PermanentError exactly as the real adapter would.
  class MockAdapter < Adapter
    attr_reader :key

    def initialize(key:, workspace: nil, account: nil)
      @key = key.to_s
      @workspace = workspace
      super(account: account)
    end

    def connect(authorization_code: nil)
      fetch_profile
    end

    def refresh_authorization
      CredentialsDto.new(
        access_token: "mock-access-#{seed}",
        refresh_token: "mock-refresh-#{seed}",
        expires_at: 60.days.from_now
      )
    end

    def fetch_profile
      ProfileDto.new(
        provider: key,
        external_account_id: "mock-#{key}-#{seed}",
        username: handle,
        display_name: workspace_name,
        avatar_url: nil,
        granted_scopes: definition ? definition.capabilities.supported.map(&:to_s) : [],
        token_expires_at: 60.days.from_now
      )
    end

    def publish(request)
      require_capability!(:publish_image)
      raise NotImplementedError, "mock publishing arrives with the publishing phase"
    end

    def fetch_analytics(since:, until_date:)
      raise NotImplementedError, "mock analytics arrives with the analytics phase"
    end

    private

    def workspace = @workspace || account&.workspace
    def workspace_name = workspace&.name || "Demo Account"

    # Deterministic per workspace and provider, so reconnecting returns the
    # same account rather than creating a duplicate.
    def seed
      Digest::SHA256.hexdigest("#{workspace&.id}-#{key}").first(10)
    end

    def handle
      base = workspace_name.parameterize(separator: ".")
      base.presence || "demo.account"
    end
  end
end
