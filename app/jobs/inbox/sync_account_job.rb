module Inbox
  # Pulls conversations for one connected account.
  #
  # Skips a platform that has no such API rather than calling it and handling
  # the error: TikTok publishes no comment or message API at all, so asking is
  # not a failure to report, it is a question that should never be asked
  # (spec 30).
  class SyncAccountJob < ApplicationJob
    queue_as :default

    ATTEMPTS = 3

    retry_on SocialProvider::TransientError, wait: :polynomially_longer, attempts: ATTEMPTS

    def perform(social_account_id, since: nil)
      account = SocialAccount.find_by(id: social_account_id)
      return if account.nil? || !account.usable_for_publishing?
      return unless readable?(account)

      threads = adapter_for(account).fetch_conversations(since: since || default_since(account))

      Array(threads).each { |thread| Inbox::ImportConversation.call(account: account, dto: thread) }
    rescue SocialProvider::PermanentError => e
      # Includes the honest "no connection has been built" case. Logged rather
      # than raised: there is nothing to retry and nothing the owner can do.
      Rails.logger.info(message: "inbox sync unavailable", provider: account&.provider,
                        workspace_id: account&.workspace_id, code: e.code)
    end

    private

    def readable?(account)
      capabilities = account.capabilities
      return false if capabilities.nil?

      capabilities.read_comments? || capabilities.direct_messages? || capabilities.reviews?
    end

    def adapter_for(account)
      SocialProvider::Registry.for(account.provider, workspace: account.workspace, account: account)
    end

    # Overlaps the last sync deliberately. A thread updated in the same second
    # as the previous run would otherwise be missed for ever.
    def default_since(account)
      last = account.conversations.maximum(:last_message_at)
      last ? last - 1.hour : 30.days.ago
    end
  end
end
