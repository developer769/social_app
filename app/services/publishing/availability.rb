module Publishing
  # Whether Prachar can genuinely publish anything at all right now.
  #
  # Read by the interface so it never offers automatic publishing it cannot
  # perform, and by the dispatcher so a due post becomes a reminder rather than
  # a failure (spec 30).
  module Availability
    module_function

    # True only when a real adapter is registered for that platform. Every
    # provider is mocked today, so this is false everywhere -- and saying so is
    # the point, rather than discovering it at the scheduled minute.
    def publishable?(provider) = !SocialProvider::Registry.mocked?(provider)

    def any_publishable?(workspace)
      workspace.social_accounts.connected.any? { |account| publishable?(account.provider) }
    end

    # What a post would do if it were scheduled right now.
    def mode_for(post)
      Preflight.new(post).any_publishable? ? "automatic" : "reminder"
    end
  end
end
