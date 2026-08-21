class CreateAdCampaigns < ActiveRecord::Migration[8.1]
  def change
    # Money put behind one post on one platform.
    #
    # Always tied to a post, because advertising something never run
    # organically means paying to find out what a free post would have told
    # you. Nothing here places an ad: that needs an adapter that can spend
    # money, and none exists.
    create_table :ad_campaigns do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.references :social_account, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }

      t.string :provider, null: false
      t.string :name, null: false
      t.string :objective, null: false, default: "reach"
      t.string :status, null: false, default: "draft"

      # Minor units and a currency, never a float. A budget is money and money
      # is not a decimal (spec 3: India-first, never hardcoded).
      t.bigint :daily_budget_minor
      t.bigint :total_budget_minor
      t.string :currency, null: false, default: "INR"

      t.date :starts_on
      t.date :ends_on

      t.string :external_id
      t.string :error_message
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :ad_campaigns, %i[workspace_id status]
    add_index :ad_campaigns, %i[social_account_id external_id], unique: true,
      where: "external_id IS NOT NULL"

    add_check_constraint :ad_campaigns,
      "status IN ('draft','pending','running','paused','finished','failed')",
      name: "ad_campaigns_status_is_known"
    add_check_constraint :ad_campaigns,
      "objective IN ('reach','engagement','traffic','messages','leads')",
      name: "ad_campaigns_objective_is_known"
    add_check_constraint :ad_campaigns,
      "daily_budget_minor IS NULL OR daily_budget_minor > 0",
      name: "ad_campaigns_daily_budget_is_positive"
    add_check_constraint :ad_campaigns,
      "total_budget_minor IS NULL OR total_budget_minor > 0",
      name: "ad_campaigns_total_budget_is_positive"
    add_check_constraint :ad_campaigns,
      "ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on",
      name: "ad_campaigns_ends_after_it_starts"

    # One day of one campaign, as the platform reported it.
    #
    # Daily rows rather than a running total, so a trend is real data rather
    # than a line drawn between two points. Every figure is nullable on
    # purpose: platforms report different things, and a metric a platform does
    # not provide must stay NULL rather than become a zero that reads as "none"
    # (the measured-vs-unavailable rule).
    create_table :ad_metrics do |t|
      t.references :ad_campaign, null: false, foreign_key: true
      t.date :on_date, null: false

      t.bigint :spend_minor
      t.string :currency, null: false, default: "INR"
      t.bigint :impressions
      t.bigint :reach
      t.bigint :clicks
      t.bigint :results
      t.string :result_kind

      t.datetime :fetched_at, null: false

      t.timestamps
    end

    # Re-fetching a day must correct it, never add a second copy of it.
    add_index :ad_metrics, %i[ad_campaign_id on_date], unique: true

    add_check_constraint :ad_metrics,
      "spend_minor IS NULL OR spend_minor >= 0", name: "ad_metrics_spend_is_not_negative"
    add_check_constraint :ad_metrics,
      "impressions IS NULL OR impressions >= 0", name: "ad_metrics_impressions_is_not_negative"
    add_check_constraint :ad_metrics,
      "reach IS NULL OR reach >= 0", name: "ad_metrics_reach_is_not_negative"
    add_check_constraint :ad_metrics,
      "clicks IS NULL OR clicks >= 0", name: "ad_metrics_clicks_is_not_negative"
  end
end
