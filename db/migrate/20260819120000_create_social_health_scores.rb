class CreateSocialHealthScores < ActiveRecord::Migration[8.1]
  def change
    create_table :social_health_scores do |t|
      t.references :workspace, null: false, foreign_key: true

      t.integer :score, null: false
      t.string :rating, null: false
      # What share of the scoring model could actually be measured. A score
      # built from four of seven signals must say so rather than presenting
      # itself as complete (spec 22: explain score calculations).
      t.integer :coverage_percentage, null: false
      t.jsonb :components, null: false, default: []
      t.datetime :computed_at, null: false

      t.timestamps
    end

    add_index :social_health_scores, %i[workspace_id computed_at], order: { computed_at: :desc }

    add_check_constraint :social_health_scores, "score BETWEEN 0 AND 100", name: "social_health_score_in_range"
    add_check_constraint :social_health_scores, "coverage_percentage BETWEEN 0 AND 100", name: "social_health_coverage_in_range"
    add_check_constraint :social_health_scores,
      "rating IN ('needs_work','fair','good','excellent')",
      name: "social_health_rating_is_known"
  end
end
