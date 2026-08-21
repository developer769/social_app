module Inbox
  # Answers one conversation.
  #
  # The message row is written BEFORE the provider is called, so a reply that
  # fails on its way out is still visible with the reason -- rather than
  # vanishing and leaving the owner unsure whether it was sent.
  class SendReply < ApplicationCommand
    def initialize(conversation:, body:, actor:)
      @conversation = conversation
      @body = body.to_s.strip
      @actor = actor
    end

    def call
      return Result.failure(:empty) if @body.blank?
      return Result.failure(:too_long) if @body.length > 5_000
      return Result.failure(:not_repliable) unless @conversation.repliable?

      message = @conversation.messages.create!(
        direction: "outbound", body: @body, sent_by: @actor,
        delivery_status: "sending", sent_at: Time.current
      )

      deliver(message)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end

    private

    def deliver(message)
      account = @conversation.social_account
      adapter = SocialProvider::Registry.for(account.provider, workspace: account.workspace,
                                                              account: account)

      result = adapter.send_reply(conversation: @conversation, body: @body)
      message.mark_sent!(external_id: result.try(:external_id))
      @conversation.touch(:last_message_at)

      Result.success(message)
    rescue SocialProvider::PermanentError => e
      message.mark_failed!(message: e.message)
      Result.failure(message)
    rescue SocialProvider::TransientError => e
      message.mark_failed!(message: "#{account.provider_name} could not be reached. Try again shortly.")
      Rails.logger.warn(message: "inbox reply failed", conversation_id: @conversation.id,
                        error: e.class.name)
      Result.failure(message)
    end
  end
end
