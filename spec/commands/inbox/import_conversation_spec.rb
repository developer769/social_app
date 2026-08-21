require "rails_helper"

RSpec.describe Inbox::ImportConversation do
  let(:workspace) { create(:workspace) }
  let(:account) { create(:social_account, workspace: workspace, provider: "instagram") }

  def dto(external_id: "t1", messages: [], **overrides)
    SocialProvider::ConversationDto.new(
      external_id: external_id, kind: "comment", participant_name: "Meera Joshi",
      participant_handle: "@meera", preview: "Do you deliver?",
      last_message_at: 1.hour.ago, messages: messages, **overrides
    )
  end

  def message(body:, direction: "inbound", external_id: nil, sent_at: 1.hour.ago)
    SocialProvider::MessageDto.new(body: body, direction: direction,
                                   external_id: external_id, sent_at: sent_at)
  end

  it "writes a thread and its messages" do
    result = described_class.call(
      account: account,
      dto: dto(messages: [ message(body: "Do you deliver?", external_id: "m1") ])
    )

    conversation = result.value
    expect(conversation).to be_persisted
    expect(conversation.workspace).to eq(workspace)
    expect(conversation.participant_name).to eq("Meera Joshi")
    expect(conversation.messages.map(&:body)).to eq([ "Do you deliver?" ])
  end

  # Syncs overlap on purpose, so this runs on already-seen threads constantly.
  # Duplicating them would fill the inbox with the same conversation.
  describe "running twice" do
    it "updates the thread rather than creating a second one" do
      described_class.call(account: account, dto: dto(preview: "First"))

      expect { described_class.call(account: account, dto: dto(preview: "Second")) }
        .not_to change(Conversation, :count)

      expect(Conversation.last.preview).to eq("Second")
    end

    it "does not import the same message twice" do
      payload = dto(messages: [ message(body: "Do you deliver?", external_id: "m1") ])

      described_class.call(account: account, dto: payload)
      expect { described_class.call(account: account, dto: payload) }.not_to change(Message, :count)
    end

    it "adds a message that is genuinely new" do
      described_class.call(account: account, dto: dto(messages: [ message(body: "First", external_id: "m1") ]))

      described_class.call(account: account, dto: dto(messages: [
        message(body: "First", external_id: "m1"),
        message(body: "And another thing", external_id: "m2", sent_at: 10.minutes.ago)
      ]))

      expect(Conversation.last.messages.map(&:body)).to eq([ "First", "And another thing" ])
    end
  end

  # A customer who writes again after being marked done is waiting on an
  # answer, and leaving the thread closed would hide them.
  it "reopens a closed thread when the customer writes again" do
    described_class.call(account: account, dto: dto)
    conversation = Conversation.last
    conversation.close!(actor: create(:user))

    described_class.call(account: account, dto: dto(messages: [
      message(body: "Hello? Still waiting", external_id: "m9", sent_at: Time.current)
    ]))

    expect(conversation.reload).to be_open
  end

  it "leaves a closed thread closed when nothing new has arrived" do
    described_class.call(account: account, dto: dto(messages: [ message(body: "Hi", external_id: "m1") ]))
    conversation = Conversation.last
    conversation.close!(actor: create(:user))

    described_class.call(account: account, dto: dto(messages: [ message(body: "Hi", external_id: "m1") ]))

    expect(conversation.reload).to be_closed
  end

  it "tracks when the customer last wrote, so the queue can be ordered" do
    described_class.call(account: account, dto: dto(messages: [
      message(body: "Older", external_id: "m1", sent_at: 3.hours.ago),
      message(body: "Newer", external_id: "m2", sent_at: 30.minutes.ago)
    ]))

    expect(Conversation.last.last_inbound_at).to be_within(1.second).of(30.minutes.ago)
  end

  # Ours already, so worth joining up: a comment on a post we published can be
  # shown next to that post.
  it "ties a comment to the post it is about when we published that post" do
    post = create(:post, workspace: workspace)
    create(:post_target, post: post, social_account: account, status: "published",
                         remote_post_id: "IG_55", published_at: 1.day.ago)

    described_class.call(account: account, dto: dto(remote_post_id: "IG_55"))

    expect(Conversation.last.post).to eq(post)
  end

  it "still imports a comment on a post we know nothing about" do
    described_class.call(account: account, dto: dto(remote_post_id: "IG_UNKNOWN"))

    expect(Conversation.last.post).to be_nil
  end

  it "records an outbound message from the platform as already delivered" do
    described_class.call(account: account, dto: dto(messages: [
      message(body: "Yes we do", direction: "outbound", external_id: "m1")
    ]))

    expect(Conversation.last.messages.first).to be_delivery_sent
  end
end
