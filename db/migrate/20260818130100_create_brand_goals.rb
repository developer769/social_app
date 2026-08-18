class CreateBrandGoals < ActiveRecord::Migration[8.1]
  def change
    # Join tables rather than an array column: goals and tones are filtered and
    # counted across workspaces, and a check constraint keeps them honest.
    create_table :brand_goals do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :goal, null: false
      t.timestamps
    end

    add_index :brand_goals, [ :workspace_id, :goal ], unique: true
    add_check_constraint :brand_goals,
      "goal IN ('increase_sales','generate_leads','grow_followers','boost_engagement','brand_awareness','website_visits')",
      name: "brand_goals_goal_is_known"

    create_table :brand_tones do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :tone, null: false
      t.timestamps
    end

    add_index :brand_tones, [ :workspace_id, :tone ], unique: true
    add_check_constraint :brand_tones,
      "tone IN ('friendly','elegant','playful','professional','premium','educational','bold','minimal')",
      name: "brand_tones_tone_is_known"
  end
end
