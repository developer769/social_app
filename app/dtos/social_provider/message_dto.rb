module SocialProvider
  # One message inside a thread, normalised. Lives in its own file because
  # Zeitwerk resolves a constant from the filename: defined alongside
  # ConversationDto it only existed once that file happened to load first.
  class MessageDto < ApplicationDto
    attribute :external_id, :direction, :body, :author_name, :author_handle, :sent_at

    def initialize(body:, direction: "inbound", external_id: nil, author_name: nil,
                   author_handle: nil, sent_at: nil)
      @external_id = external_id
      @direction = direction.to_s
      @body = body.to_s
      @author_name = author_name
      @author_handle = author_handle
      @sent_at = sent_at
      freeze
    end
  end
end
