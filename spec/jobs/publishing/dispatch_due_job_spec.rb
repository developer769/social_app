require "rails_helper"

RSpec.describe Publishing::DispatchDueJob do
  let(:workspace) { create(:workspace) }
  let(:account) { create(:social_account, workspace: workspace) }

  def scheduled_at(time)
    post = create(:post, workspace: workspace, status: "scheduled",
                         scheduled_at: time, scheduled_timezone: workspace.timezone)
    create(:post_target, post: post, social_account: account)
    post
  end

  it "picks up a post whose time has come" do
    post = scheduled_at(1.minute.ago)

    expect { described_class.perform_now }.to have_enqueued_job(Publishing::PublishPostJob).with(post.id)
    expect(post.reload).to be_publishing
  end

  it "leaves a post whose time has not come" do
    post = scheduled_at(1.hour.from_now)

    expect { described_class.perform_now }.not_to have_enqueued_job(Publishing::PublishPostJob)
    expect(post.reload).to be_scheduled
  end

  it "ignores drafts and cancelled posts even when their time has passed" do
    %w[draft cancelled published failed].each do |status|
      post = scheduled_at(1.minute.ago)
      post.update_columns(status: status)
    end

    expect { described_class.perform_now }.not_to have_enqueued_job(Publishing::PublishPostJob)
  end

  # Two sweeps overlapping must not both hand the same post on. The second
  # publish is the one that cannot be taken back.
  it "hands a post on exactly once, even when two sweeps overlap" do
    post = scheduled_at(1.minute.ago)

    expect {
      described_class.perform_now
      described_class.perform_now
    }.to have_enqueued_job(Publishing::PublishPostJob).with(post.id).exactly(:once)
  end

  describe "a post whose time passed while nothing was running" do
    # Late is a decision the owner can see and undo. Silently skipped is not.
    it "still publishes something only hours late" do
      post = scheduled_at(3.hours.ago)

      expect { described_class.perform_now }.to have_enqueued_job(Publishing::PublishPostJob)
      expect(post.reload).to be_publishing
    end

    # Posting last week's festival offer today is worse than not posting it.
    it "refuses to publish something long past, and says why" do
      post = scheduled_at(3.days.ago)

      expect { described_class.perform_now }.not_to have_enqueued_job(Publishing::PublishPostJob)

      expect(post.reload).to be_failed
      expect(post.post_targets.first.error_code).to eq("missed_window")
      expect(post.post_targets.first.error_message).to include("its time passed")
    end

    it "records that it was missed rather than letting it vanish" do
      scheduled_at(3.days.ago)

      expect { described_class.perform_now }
        .to change { AuditEvent.where(action: "post.missed_window").count }.by(1)
    end
  end

  it "sweeps every workspace, not just one" do
    mine = scheduled_at(1.minute.ago)
    other_workspace = create(:workspace)
    theirs = create(:post, workspace: other_workspace, status: "scheduled",
                           scheduled_at: 1.minute.ago, scheduled_timezone: "Asia/Kolkata")
    create(:post_target, post: theirs, social_account: create(:social_account, workspace: other_workspace))

    described_class.perform_now

    expect(mine.reload).to be_publishing
    expect(theirs.reload).to be_publishing
  end
end
