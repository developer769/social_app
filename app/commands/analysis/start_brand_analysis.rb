module Analysis
  # Creates an analysis with one row per task, then enqueues one job per task.
  #
  # Rows are created before any job runs, so the screen can show the full list
  # as "queued" immediately rather than filling in as jobs happen to start.
  class StartBrandAnalysis < ApplicationCommand
    def initialize(workspace:, actor: nil)
      @workspace = workspace
      @actor = actor
    end

    def call
      analysis = nil

      ActiveRecord::Base.transaction do
        analysis = @workspace.brand_analyses.create!(
          requested_by: @actor, status: "analyzing", started_at: Time.current
        )

        ::BrandAnalysis::TASK_KEYS.each do |task_key|
          analysis.tasks.create!(task_key: task_key, status: "queued")
        end

        AuditEvent.record!(
          action: "brand_analysis.started",
          workspace: @workspace,
          actor_user: @actor,
          auditable: analysis
        )
      end

      # Enqueued after the transaction commits, so a job cannot start before
      # its row is visible to other connections.
      analysis.tasks.each { |task| RunTaskJob.perform_later(task.id) }

      Result.success(analysis)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end
  end
end
