require "rails_helper"

RSpec.describe BrandAnalysis do
  let(:workspace) { create(:workspace) }
  let(:analysis) { workspace.brand_analyses.create!(status: "analyzing") }

  describe "progress" do
    # The specification forbids a timer-driven percentage, so progress must be
    # countable from the task rows and nothing else.
    it "counts finished tasks, not elapsed time" do
      # Ordered explicitly: an unordered limit returns arbitrary rows, which
      # made this assertion depend on PostgreSQL's row order.
      tasks = Array.new(4) { |i| analysis.tasks.create!(task_key: described_class::TASK_KEYS[i]) }

      expect(analysis.progress_percentage).to eq(0)

      tasks[0].finish!(outcome: "analysed")
      expect(analysis.reload.progress_percentage).to eq(25)

      tasks[1].finish!(outcome: "not_supported")
      expect(analysis.reload.progress_percentage).to eq(50)

      tasks[2].finish!(outcome: "error", error_message: "boom")
      expect(analysis.reload.progress_percentage).to eq(75)
    end

    it "is zero with no tasks rather than dividing by zero" do
      expect(analysis.progress_percentage).to eq(0)
    end
  end

  describe "settling" do
    it "is complete only when every task actually analysed something" do
      2.times { |i| analysis.tasks.create!(task_key: described_class::TASK_KEYS[i]) }
      analysis.tasks.each { |t| t.finish!(outcome: "analysed") }

      analysis.refresh_status!

      expect(analysis.reload).to be_complete
    end

    it "is partially complete when some tasks had no data to work with" do
      2.times { |i| analysis.tasks.create!(task_key: described_class::TASK_KEYS[i]) }
      analysis.tasks.first.finish!(outcome: "analysed")
      analysis.tasks.last.finish!(outcome: "not_supported")

      analysis.refresh_status!

      expect(analysis.reload).to be_partially_complete
    end

    it "fails only when every task failed" do
      2.times { |i| analysis.tasks.create!(task_key: described_class::TASK_KEYS[i]) }
      analysis.tasks.each { |t| t.finish!(outcome: "error", error_message: "boom") }

      analysis.refresh_status!

      expect(analysis.reload).to be_failed
    end

    it "does not settle while a task is still running" do
      2.times { |i| analysis.tasks.create!(task_key: described_class::TASK_KEYS[i]) }
      analysis.tasks.first.finish!(outcome: "analysed")

      analysis.refresh_status!

      expect(analysis.reload).to be_analyzing
      expect(analysis.finished_at).to be_nil
    end
  end

  it "refuses an unknown outcome" do
    task = analysis.tasks.create!(task_key: "profile_health")

    expect { task.finish!(outcome: "vibes") }.to raise_error(ArgumentError, /unknown outcome/)
  end
end
