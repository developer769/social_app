require "rails_helper"

RSpec.describe Posts::CalendarQuery do
  let(:workspace) { create(:workspace, timezone: "Asia/Kolkata") }
  let(:zone) { ActiveSupport::TimeZone["Asia/Kolkata"] }

  def post_at(local_time, **attributes)
    create(:post, workspace: workspace, status: "scheduled",
           scheduled_at: zone.parse(local_time), scheduled_timezone: "Asia/Kolkata", **attributes)
  end

  describe "grouping by day" do
    # IST is UTC+5:30, so a post just after midnight local time is on the
    # PREVIOUS day in UTC. Grouping by UTC date would put it in the wrong box.
    it "groups by the day the workspace would recognise, not the UTC day" do
      post = post_at("2026-09-10 00:30")

      calendar = described_class.new(workspace: workspace, view: "month", date: "2026-09-10")

      expect(post.scheduled_at.utc.to_date).to eq(Date.new(2026, 9, 9))
      expect(calendar.posts_by_date[Date.new(2026, 9, 10)]).to include(post)
      expect(calendar.posts_by_date[Date.new(2026, 9, 9)]).to be_nil
    end

    it "keeps a late-evening post on its own day" do
      post = post_at("2026-09-10 23:45")

      calendar = described_class.new(workspace: workspace, view: "month", date: "2026-09-10")

      expect(calendar.posts_by_date[Date.new(2026, 9, 10)]).to include(post)
    end
  end

  describe "periods" do
    it "covers whole weeks either side of the month, so the grid has no gaps" do
      calendar = described_class.new(workspace: workspace, view: "month", date: "2026-09-15")

      expect(calendar.days.size % 7).to eq(0)
      expect(calendar.period.starts_on).to be <= Date.new(2026, 9, 1)
      expect(calendar.period.ends_on).to be >= Date.new(2026, 9, 30)
    end

    it "shows exactly seven days in the week view" do
      expect(described_class.new(workspace: workspace, view: "week", date: "2026-09-15").days.size).to eq(7)
    end

    it "shows one day in the day view" do
      expect(described_class.new(workspace: workspace, view: "day", date: "2026-09-15").days).to eq([ Date.new(2026, 9, 15) ])
    end

    it "looks forward thirty days in the agenda view, regardless of the date given" do
      calendar = described_class.new(workspace: workspace, view: "agenda", date: "2020-01-01")

      expect(calendar.period.starts_on).to eq(zone.today)
      expect(calendar.days.size).to eq(30)
    end
  end

  describe "input it does not recognise" do
    it "falls back to the month view rather than erroring" do
      expect(described_class.new(workspace: workspace, view: "spiral").view).to eq("month")
    end

    it "falls back to today when the date is unparseable" do
      expect(described_class.new(workspace: workspace, date: "not-a-date").anchor).to eq(zone.today)
    end
  end

  describe "filtering" do
    let(:account) { create(:social_account, workspace: workspace, provider: "instagram") }

    it "narrows to one platform" do
      matching = post_at("2026-09-10 10:00")
      create(:post_target, post: matching, social_account: account)
      other = post_at("2026-09-11 10:00")

      calendar = described_class.new(workspace: workspace, view: "month", date: "2026-09-10", provider: "instagram")

      expect(calendar.posts).to include(matching)
      expect(calendar.posts).not_to include(other)
    end

    it "narrows to one status" do
      scheduled = post_at("2026-09-10 10:00")
      draft = create(:post, workspace: workspace, status: "draft",
                     scheduled_at: zone.parse("2026-09-11 10:00"), scheduled_timezone: "Asia/Kolkata")

      calendar = described_class.new(workspace: workspace, view: "month", date: "2026-09-10", status: "scheduled")

      expect(calendar.posts).to contain_exactly(scheduled)
      expect(calendar.posts).not_to include(draft)
    end

    it "never shows a cancelled post" do
      cancelled = post_at("2026-09-10 10:00")
      cancelled.cancel!

      calendar = described_class.new(workspace: workspace, view: "month", date: "2026-09-10")

      expect(calendar.posts).to be_empty
    end
  end

  describe "tenancy" do
    it "cannot see another workspace's posts" do
      other = create(:workspace)
      create(:post, workspace: other, status: "scheduled",
             scheduled_at: zone.parse("2026-09-10 10:00"), scheduled_timezone: "Asia/Kolkata")

      calendar = described_class.new(workspace: workspace, view: "month", date: "2026-09-10")

      expect(calendar.posts).to be_empty
    end
  end
end
