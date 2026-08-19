require "rails_helper"

RSpec.describe Analysis::RunTaskJob do
  let(:workspace) { create(:workspace) }
  let(:analysis) { workspace.brand_analyses.create!(status: "analyzing", started_at: Time.current) }
  let(:task) { analysis.tasks.create!(task_key: "profile_health") }

  it "runs the task and records its outcome" do
    described_class.perform_now(task.id)

    expect(task.reload).to be_complete
    expect(task.outcome).to eq("analysed")
    expect(task.finished_at).to be_present
  end

  it "is safe to run twice: a finished task is not re-run" do
    described_class.perform_now(task.id)
    finished_at = task.reload.finished_at

    described_class.perform_now(task.id)

    expect(task.reload.finished_at).to eq(finished_at)
  end

  it "does nothing when the task has been deleted" do
    id = task.id
    task.destroy!

    expect { described_class.perform_now(id) }.not_to raise_error
  end

  it "records a failure on the task rather than losing it, and still re-raises for Sidekiq" do
    allow(Analysis::ProfileHealth).to receive(:call).and_raise(StandardError, "analyzer exploded")

    expect { described_class.perform_now(task.id) }.to raise_error(StandardError, "analyzer exploded")

    expect(task.reload).to be_failed
    expect(task.outcome).to eq("error")
    expect(task.error_message).to eq("analyzer exploded")
  end

  it "settles the parent analysis once every task has finished" do
    analysis.tasks.create!(task_key: "brand_voice")

    analysis.tasks.each { |t| described_class.perform_now(t.id) }

    expect(analysis.reload).to be_partially_complete
    expect(analysis.finished_at).to be_present
  end

  it "leaves the parent analysing while work remains" do
    analysis.tasks.create!(task_key: "brand_voice")

    described_class.perform_now(task.id)

    expect(analysis.reload).to be_analyzing
  end
end
