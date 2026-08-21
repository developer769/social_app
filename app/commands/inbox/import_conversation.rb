module Inbox
  # Writes one provider thread into our own tables.
  #
  # Keyed on the platform's own id so syncing the same thread twice updates it
  # rather than duplicating it -- syncs overlap on purpose, so this runs on
  # already-seen threads constantly.
  class ImportConversation < ApplicationCommand
    def initialize(account:, dto:)
      @account = account
      @dto = dto
    end

    def call
      conversation = nil

      ActiveRecord::Base.transaction do
        conversation = @account.conversations.find_or_initialize_by(external_id: @dto.external_id)

        conversation.assign_attributes(
          workspace: @account.workspace,
          provider: @account.provider,
          kind: @dto.kind,
          participant_name: @dto.participant_name,
          participant_handle: @dto.participant_handle,
          participant_external_id: @dto.participant_external_id,
          preview: @dto.preview.to_s.truncate(280).presence,
          permalink: @dto.permalink,
          rating: @dto.rating,
          post: post_for(@dto.remote_post_id),
          last_message_at: @dto.last_message_at || conversation.last_message_at || Time.current
        )

        # Reopening is deliberate: a customer who writes again after being
        # marked done is waiting on an answer, and leaving the thread closed
        # would hide them.
        conversation.status = "open" if reopening?(conversation)
        conversation.save!

        import_messages(conversation)
      end

      Result.success(conversation)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end

    private

    def reopening?(conversation)
      return false if conversation.new_record? || conversation.open?

      inbound = @dto.messages.select { |message| message.direction == "inbound" }
      inbound.any? { |message| message.sent_at.present? && message.sent_at > conversation.closed_at.to_time }
    end

    def import_messages(conversation)
      latest_inbound = conversation.last_inbound_at

      @dto.messages.each do |dto|
        next if dto.external_id.present? &&
                conversation.messages.exists?(external_id: dto.external_id)

        message = conversation.messages.create!(
          external_id: dto.external_id,
          direction: dto.direction,
          body: dto.body,
          author_name: dto.author_name,
          author_handle: dto.author_handle,
          sent_at: dto.sent_at || Time.current,
          # Anything arriving from the platform has already been delivered.
          delivery_status: (dto.direction == "outbound" ? "sent" : nil)
        )

        if message.inbound? && (latest_inbound.nil? || message.sent_at > latest_inbound)
          latest_inbound = message.sent_at
        end
      end

      conversation.update!(last_inbound_at: latest_inbound) if latest_inbound != conversation.last_inbound_at
    end

    # Ties a comment back to the post it is about, when we published that post
    # ourselves and therefore know its remote id.
    def post_for(remote_post_id)
      return if remote_post_id.blank?

      PostTarget.find_by(social_account_id: @account.id, remote_post_id: remote_post_id)&.post
    end
  end
end
