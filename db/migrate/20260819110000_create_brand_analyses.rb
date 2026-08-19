class CreateBrandAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :brand_analyses do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :requested_by, foreign_key: { to_table: :users }

      t.string :status, null: false, default: "queued"
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :brand_analyses, %i[workspace_id created_at], order: { created_at: :desc }

    add_check_constraint :brand_analyses,
      "status IN ('queued','analyzing','partially_complete','complete','failed')",
      name: "brand_analyses_status_is_known"

    # One row per sub-task with its own real state. Progress is counted from
    # these rows, never from a timer (spec 22).
    create_table :brand_analysis_tasks do |t|
      t.references :brand_analysis, null: false, foreign_key: true
      t.string :task_key, null: false
      t.string :status, null: false, default: "queued"
      t.jsonb :result, null: false, default: {}
      t.string :outcome
      t.string :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :brand_analysis_tasks, %i[brand_analysis_id task_key], unique: true

    add_check_constraint :brand_analysis_tasks,
      "status IN ('queued','analyzing','complete','failed')",
      name: "brand_analysis_tasks_status_is_known"
    # A finished task records WHY it produced what it did, so "no result" is
    # never confused with "bad result".
    add_check_constraint :brand_analysis_tasks,
      "outcome IS NULL OR outcome IN ('analysed','insufficient_data','not_supported','error')",
      name: "brand_analysis_tasks_outcome_is_known"
  end
end
