require "rails_helper"

RSpec.describe Inbox::SyncAccountJob do
  let(:workspace) { create(:workspace) }

  def account_for(provider) = create(:social_account, workspace: workspace, provider: provider)

  def adapter_returning(threads)
    instance_double(SocialProvider::Adapter).tap do |adapter|
      allow(adapter).to receive(:fetch_conversations).and_return(threads)
    end
  end

  def thread(external_id: "t1")
    SocialProvider::ConversationDto.new(
      external_id: external_id, kind: "comment", participant_name: "Meera",
      preview: "Do you deliver?", last_message_at: 1.hour.ago,
      messages: [ SocialProvider::MessageDto.new(body: "Do you deliver?", external_id: "m1") ]
    )
  end

  it "imports what the provider returns" do
    account = account_for("instagram")
    allow(SocialProvider::Registry).to receive(:for).and_return(adapter_returning([ thread ]))

    expect { described_class.perform_now(account.id) }.to change(Conversation, :count).by(1)
  end

  # Spec 30. TikTok publishes no comment or message API at all, so asking is not
  # a failure to report -- it is a question that should never be asked.
  it "never calls a platform that has no such API" do
    account = account_for("tiktok")
    adapter = adapter_returning([ thread ])
    allow(SocialProvider::Registry).to receive(:for).and_return(adapter)

    described_class.perform_now(account.id)

    expect(adapter).not_to have_received(:fetch_conversations)
  end

  # The honest "no connection has been built" refusal. Nothing to retry and
  # nothing the owner can do, so it must not surface as an error.
  it "stays quiet when the provider says it cannot read messages yet" do
    account = account_for("instagram")

    expect { described_class.perform_now(account.id) }.not_to raise_error
    expect(Conversation.count).to eq(0)
  end

  it "does nothing for an account that is no longer usable" do
    account = account_for("instagram")
    account.update!(connection_status: "disconnected")
    adapter = adapter_returning([ thread ])
    allow(SocialProvider::Registry).to receive(:for).and_return(adapter)

    described_class.perform_now(account.id)

    expect(adapter).not_to have_received(:fetch_conversations)
  end

  it "survives the account being deleted before a worker picks it up" do
    account = account_for("instagram")
    id = account.id
    account.destroy!

    expect { described_class.perform_now(id) }.not_to raise_error
  end

  # Syncs overlap deliberately: a thread updated in the same second as the last
  # run would otherwise be missed for ever.
  it "asks for a window that overlaps the last thread it saw" do
    account = account_for("instagram")
    create(:conversation, workspace: workspace, social_account: account,
                          provider: "instagram", last_message_at: 2.hours.ago)
    adapter = adapter_returning([])
    allow(SocialProvider::Registry).to receive(:for).and_return(adapter)

    described_class.perform_now(account.id)

    expect(adapter).to have_received(:fetch_conversations) do |since:|
      expect(since).to be < 2.hours.ago
    end
  end

  it "looks back a month on the first sync" do
    account = account_for("instagram")
    adapter = adapter_returning([])
    allow(SocialProvider::Registry).to receive(:for).and_return(adapter)

    described_class.perform_now(account.id)

    expect(adapter).to have_received(:fetch_conversations) do |since:|
      expect(since).to be_within(1.minute).of(30.days.ago)
    end
  end
end
