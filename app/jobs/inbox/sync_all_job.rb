module Inbox
  # Sweeps every connected account that can be read.
  #
  # One job per account rather than one big one, so a single platform being slow
  # cannot delay everybody else's inbox, and a failure is scoped to the account
  # it belongs to.
  class SyncAllJob < ApplicationJob
    queue_as :default

    def perform
      SocialAccount.connected.find_each do |account|
        next unless account.usable_for_publishing?
        # Asking a platform that publishes no such API is a question that should
        # never be asked (spec 30), and the per-account job checks it again.
        next unless readable?(account)

        SyncAccountJob.perform_later(account.id)
      end
    end

    private

    def readable?(account)
      capabilities = account.capabilities
      return false if capabilities.nil?

      capabilities.read_comments? || capabilities.direct_messages? || capabilities.reviews?
    end
  end
end
