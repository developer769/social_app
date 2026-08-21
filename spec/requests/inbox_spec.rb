require "rails_helper"

RSpec.describe "Inbox" do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace, owner_user: owner) }

  before do
    create(:workspace_membership, workspace: workspace, user: owner)
    sign_in(owner)
  end

  def slug = { workspace_slug: workspace.slug }
  def body_text = response.body.gsub(/\s+/, " ")

  def account_for(provider) = create(:social_account, workspace: workspace, provider: provider)

  def conversation_for(account, **attrs)
    create(:conversation, workspace: workspace, social_account: account,
                          provider: account.provider, **attrs)
  end

  # An empty inbox with no explanation reads as "nobody has messaged you",
  # which is a claim about the business rather than about Prachar.
  describe "when nothing can be read yet" do
    before { account_for("instagram") }

    it "says the inbox has never been filled, not that it is empty" do
      get workspace_inbox_path(**slug)

      expect(body_text).to include("Prachar cannot read your messages yet")
      expect(body_text).to include("it is one that has never been filled")
    end

    it "names the platform it cannot reach" do
      get workspace_inbox_path(**slug)

      expect(body_text).to include("No connection to Instagram has been built")
    end
  end

  # Spec 30. Offering a filter for something the platform has no API for is a
  # promise that cannot be kept.
  describe "what it offers per platform" do
    it "offers no Reviews filter when no connected platform has reviews" do
      account_for("instagram")

      get workspace_inbox_path(**slug)

      expect(response.body).to include("Comments").and include("Messages")
      expect(body_text).not_to match(/>\s*Reviews\s*</)
    end

    it "offers a Reviews filter when a platform provides them" do
      account_for("google_business")

      get workspace_inbox_path(**slug)

      expect(body_text).to match(/>\s*Reviews\s*</)
    end

    # TikTok publishes no comment or message API at all. That is never, not
    # "not yet", and saying "once connected" would be wrong.
    it "says a platform with no such API will never appear here" do
      account_for("tiktok")

      get workspace_inbox_path(**slug)

      expect(body_text).to include("will ever appear in an inbox")
      expect(body_text).not_to include("TikTok — once connected")
    end
  end

  describe "the list" do
    let(:account) { account_for("instagram") }

    it "shows open conversations, newest first" do
      conversation_for(account, external_id: "a", participant_name: "Meera",
                                last_message_at: 1.hour.ago)
      conversation_for(account, external_id: "b", participant_name: "Rohit",
                                last_message_at: 3.days.ago)

      get workspace_inbox_path(**slug)

      expect(response.body).to include("Meera").and include("Rohit")
      expect(response.body.index("Meera")).to be < response.body.index("Rohit")
    end

    # An inbox that shows everything ever received stops being a queue.
    it "hides conversations marked done unless asked for them" do
      conversation_for(account, external_id: "done", participant_name: "Settled",
                                status: "closed", closed_at: 1.day.ago, last_message_at: 1.hour.ago)

      get workspace_inbox_path(**slug)
      expect(response.body).not_to include("Settled")

      get workspace_inbox_path(**slug, status: "closed")
      expect(response.body).to include("Settled")
    end

    it "marks a conversation waiting on the business" do
      conversation = conversation_for(account, external_id: "waiting", participant_name: "Meera",
                                               last_message_at: 1.hour.ago, last_inbound_at: 1.hour.ago)
      conversation.messages.create!(direction: "inbound", body: "Do you deliver?", sent_at: 1.hour.ago)

      get workspace_inbox_path(**slug)

      expect(response.body).to include("Waiting on you")
    end

    it "filters by kind" do
      conversation_for(account, external_id: "c", kind: "comment", participant_name: "Commenter",
                                last_message_at: 1.hour.ago)
      conversation_for(account, external_id: "d", kind: "direct_message", participant_name: "Messenger",
                                last_message_at: 1.hour.ago)

      get workspace_inbox_path(**slug, kind: "direct_message")

      expect(response.body).to include("Messenger")
      expect(response.body).not_to include("Commenter")
    end
  end

  describe "one conversation" do
    let(:account) { account_for("instagram") }
    let(:conversation) do
      conversation_for(account, external_id: "x", participant_name: "Meera", last_message_at: 1.hour.ago)
    end

    it "shows the thread" do
      conversation.messages.create!(direction: "inbound", body: "Do you deliver to Vaishali Nagar?",
                                    sent_at: 1.hour.ago)

      get workspace_conversation_path(**slug, id: conversation)

      expect(response.body).to include("Do you deliver to Vaishali Nagar?")
    end

    # Spec 27. A reply that did not leave the building must say so on itself,
    # not only in a flash message that has already gone.
    it "records a failed reply against the message rather than losing it" do
      post reply_workspace_conversation_path(**slug, id: conversation), params: { body: "Yes, we do!" }

      message = conversation.messages.reload.last
      expect(message.body).to eq("Yes, we do!")
      expect(message).to be_failed
      expect(message.error_message).to include("cannot reply on Instagram yet")

      get workspace_conversation_path(**slug, id: conversation)
      expect(body_text).to include("Not sent")
    end

    it "will not send an empty reply" do
      post reply_workspace_conversation_path(**slug, id: conversation), params: { body: "   " }

      expect(conversation.messages.reload).to be_empty
      expect(flash[:alert]).to include("Write something")
    end

    # Spec 30: not a broken form, no form at all.
    it "offers no reply box where the platform does not allow replying" do
      youtube = account_for("youtube")
      dm = conversation_for(youtube, external_id: "yt", kind: "direct_message",
                                     last_message_at: 1.hour.ago)

      get workspace_conversation_path(**slug, id: dm)

      expect(body_text).to include("Replying is not possible here")
      expect(response.body).not_to include('name="body"')
    end

    it "marks a conversation done and takes it out of the queue" do
      patch close_workspace_conversation_path(**slug, id: conversation)

      expect(conversation.reload).to be_closed
      expect(conversation.closed_by).to eq(owner)
    end

    it "reopens one that was marked done" do
      conversation.close!(actor: owner)

      patch reopen_workspace_conversation_path(**slug, id: conversation)

      expect(conversation.reload).to be_open
    end
  end

  describe "saved replies" do
    it "keeps an answer for later" do
      expect {
        post workspace_saved_replies_path(**slug),
             params: { saved_reply: { title: "Delivery areas", body: "We deliver across Jaipur." } }
      }.to change(SavedReply, :count).by(1)

      expect(SavedReply.last.created_by).to eq(owner)
    end

    it "refuses two replies with the same name" do
      create(:saved_reply, workspace: workspace, title: "Delivery areas")

      post workspace_saved_replies_path(**slug),
           params: { saved_reply: { title: "Delivery areas", body: "Something else." } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("has already been taken")
    end

    it "offers them on a conversation, ready to use" do
      create(:saved_reply, workspace: workspace, title: "Delivery areas",
                           body: "We deliver across Jaipur.")
      account = account_for("instagram")
      conversation = conversation_for(account, external_id: "z", last_message_at: 1.hour.ago)

      get workspace_conversation_path(**slug, id: conversation)

      expect(response.body).to include("Delivery areas")
      expect(response.body).to include("We deliver across Jaipur.")
    end

    it "deletes one" do
      reply = create(:saved_reply, workspace: workspace)

      expect { delete workspace_saved_reply_path(**slug, id: reply) }
        .to change(SavedReply, :count).by(-1)
    end
  end

  # Spec 7.
  describe "tenant isolation" do
    it "cannot open another workspace's conversation" do
      other = create(:workspace)
      theirs = create(:conversation, workspace: other,
                                     social_account: create(:social_account, workspace: other))

      get workspace_conversation_path(**slug, id: theirs)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot edit another workspace's saved reply" do
      other = create(:workspace)
      theirs = create(:saved_reply, workspace: other, title: "Theirs")

      patch workspace_saved_reply_path(**slug, id: theirs),
            params: { saved_reply: { title: "Mine now" } }

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.title).to eq("Theirs")
    end
  end
end
