require "rails_helper"

RSpec.describe Scheduling::MonthPlanner do
  let(:workspace) { create(:workspace, timezone: "Asia/Kolkata") }

  def plan(count, starting: nil)
    described_class.new(workspace: workspace, count: count, starting: starting).call
  end

  def prefer(days:, per_week: 7, at: "10:00")
    create(:posting_preference, workspace: workspace, preferred_days: days,
                                posts_per_week: per_week, preferred_time: at)
  end

  def local(time) = time.in_time_zone("Asia/Kolkata")

  it "puts posts only on the days the owner chose" do
    prefer(days: [ 2, 4 ]) # Tuesday and Thursday

    slots = plan(6).slots

    expect(slots.size).to eq(6)
    expect(slots.map { |s| local(s).wday }.uniq).to contain_exactly(2, 4)
  end

  it "uses the owner's usual time, in their own timezone" do
    prefer(days: [ 1 ], at: "18:30")

    slot = plan(1).slots.first

    expect(local(slot).strftime("%H:%M")).to eq("18:30")
  end

  # Three posts a week should not all land on Monday.
  it "spreads across the week when no days are set" do
    create(:posting_preference, workspace: workspace, preferred_days: [], posts_per_week: 7)

    days = plan(3).slots.map { |s| local(s).wday }

    expect(days.uniq.size).to eq(3)
  end

  # A batch must not quietly overrule the rhythm the owner asked for. It only
  # ever slows the batch down; it never drops a post.
  it "respects how often they said they want to post" do
    prefer(days: [ 1, 2, 3, 4, 5 ], per_week: 2)

    result = plan(6)

    expect(result.count).to eq(6)
    weeks = result.slots.group_by { |s| local(s).strftime("%G-%V") }
    expect(weeks.values.map(&:size)).to all(be <= 2)
    # Six posts at two a week has to run past a fortnight.
    expect(result.spans_days).to be > 14
  end

  # Two posts at the same minute is a worse outcome than one arriving a day
  # later.
  it "never books a slot that already holds a post" do
    prefer(days: [ 1, 3, 5 ])
    taken = plan(1).slots.first
    create(:post, workspace: workspace, scheduled_at: taken,
                  scheduled_timezone: "Asia/Kolkata").update_columns(status: "scheduled")

    slots = plan(3).slots

    expect(slots).not_to include(taken)
    expect(slots.size).to eq(3)
  end

  it "ignores a cancelled post when looking for a free slot" do
    prefer(days: [ 1, 3, 5 ])
    taken = plan(1).slots.first
    create(:post, workspace: workspace, scheduled_at: taken,
                  scheduled_timezone: "Asia/Kolkata").update_columns(status: "cancelled")

    expect(plan(1).slots.first).to eq(taken)
  end

  it "never schedules anything in the past" do
    prefer(days: (0..6).to_a)

    expect(plan(5, starting: 10.days.ago.to_date).slots).to all(be > Time.current)
  end

  it "starts from the day asked for" do
    prefer(days: (0..6).to_a)
    starting = 20.days.from_now.to_date

    expect(plan(1, starting: starting).slots.first.to_date).to eq(starting)
  end

  describe "when the days simply do not fit" do
    # A workspace posting once a week that asks for fifty posts would otherwise
    # walk a year into the future.
    it "stops at the horizon and says it fell short" do
      prefer(days: [ 0 ], per_week: 1)

      result = plan(40)

      expect(result).to be_short
      expect(result).to be_horizon_reached
      expect(result.count).to be < 40
    end

    it "is not short when everything fits" do
      prefer(days: [ 1, 3, 5 ])

      expect(plan(5)).not_to be_short
    end
  end

  it "asks for nothing and gets nothing" do
    expect(plan(0).slots).to be_empty
  end

  # Spec 7: another workspace's calendar is not a constraint on this one.
  it "does not treat another workspace's posts as taken slots" do
    prefer(days: [ 1, 3, 5 ])
    taken = plan(1).slots.first
    other = create(:workspace)
    create(:post, workspace: other, scheduled_at: taken,
                  scheduled_timezone: "Asia/Kolkata").update_columns(status: "scheduled")

    expect(plan(1).slots.first).to eq(taken)
  end
end
