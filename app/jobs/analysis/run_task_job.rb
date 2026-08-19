module Analysis
  # Runs one analysis task.
  #
  # Small, workspace-aware, and safe to run twice: a task that has already
  # finished is left alone rather than re-run, so a Sidekiq retry cannot
  # overwrite a completed result (spec 31).
  class RunTaskJob < ApplicationJob
    queue_as :default

    def perform(task_id)
      task = BrandAnalysisTask.find_by(id: task_id)
      return if task.nil? || task.finished?

      task.start!
      workspace = task.brand_analysis.workspace

      outcome = Registry.for(task.task_key).call(workspace: workspace)
      task.finish!(outcome: outcome.outcome, result: outcome.result)
    rescue StandardError => e
      # Recorded rather than swallowed: the owner sees "could not complete" on
      # that row, and the detail reaches the logs for us. A failed task must not
      # take the whole analysis down with it.
      Rails.logger.error(
        message: "brand analysis task failed",
        task_id: task_id,
        task_key: task&.task_key,
        workspace_id: task&.brand_analysis&.workspace_id,
        error: e.class.name
      )
      task&.finish!(outcome: "error", error_message: e.message.truncate(200))
      raise
    ensure
      if task
        task.brand_analysis.refresh_status!
        broadcast(task.brand_analysis.reload)
      end
    end

    private

    def broadcast(analysis)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ analysis.workspace, :brand_analysis ],
        target: "brand-analysis",
        partial: "onboarding/analysis/panel",
        locals: { analysis: analysis, workspace: analysis.workspace }
      )
    end
  end
end
