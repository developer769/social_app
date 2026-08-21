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

    # Refuses, always, and says why.
    #
    # The tempting alternative is to invent a remote id and a plausible
    # permalink so the flow "works" in development. That would put "Published to
    # Instagram" in front of a business owner when nothing left the building,
    # which is the single most damaging lie this product could tell (spec 27).
    # A refusal that names itself is worth more than a demo that lies.
    def publish(request)
      capability = request.video? ? :publish_video : :publish_image
      require_capability!(capability)

      raise PermanentError.new(
        "Prachar cannot post to #{definition&.name || key} yet. "         "No connection to #{definition&.name || key} has been built, so nothing was sent.",
        code: "provider_not_connected"
      )
    end

    def publication_status(remote_id:)
      raise PermanentError.new("Nothing was published, so there is no status to check.",
                               code: "provider_not_connected")
    end

    def fetch_analytics(since:, until_date:)
      raise PermanentError.new(
        "Prachar cannot read figures from #{definition&.name || key} yet.",
        code: "provider_not_connected"
      )
    end

    # Refuses rather than inventing a plausible customer asking a plausible
    # question. A fabricated inbox is worse than an empty one: somebody would
    # try to answer it (spec 27).
    def fetch_conversations(since:)
      require_capability!(:read_comments)

      raise PermanentError.new(
        "Prachar cannot read messages from #{definition&.name || key} yet. "         "No connection to #{definition&.name || key} has been built.",
        code: "provider_not_connected"
      )
    end

    def send_reply(conversation:, body:)
      raise PermanentError.new(
        "Prachar cannot reply on #{definition&.name || key} yet, so nothing was sent.",
        code: "provider_not_connected"
      )
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
