module SocialProvider
  # One thread as a provider describes it, normalised so no platform's field
  # names reach the rest of the application (spec 11, 30).
  class ConversationDto < ApplicationDto
    attribute :external_id, :kind, :participant_name, :participant_handle,
              :participant_external_id, :preview, :permalink, :rating,
              :last_message_at, :remote_post_id, :messages

    def initialize(external_id:, kind:, participant_name: nil, participant_handle: nil,
                   participant_external_id: nil, preview: nil, permalink: nil, rating: nil,
                   last_message_at: nil, remote_post_id: nil, messages: [])
      @external_id = external_id.to_s
      @kind = kind.to_s
      @participant_name = participant_name
      @participant_handle = participant_handle
      @participant_external_id = participant_external_id
      @preview = preview
      @permalink = permalink
      @rating = rating
      @last_message_at = last_message_at
      @remote_post_id = remote_post_id
      @messages = Array(messages).freeze
      freeze
    end
  end
end
