class BrandGoal < ApplicationRecord
  include WorkspaceOwned

  GOALS = %w[increase_sales generate_leads grow_followers boost_engagement brand_awareness website_visits].freeze

  # Labels live here so the wizard, settings and AI prompt context all read the
  # same wording.
  LABELS = {
    "increase_sales" => [ "Increase sales", "Drive more purchases and grow your revenue." ],
    "generate_leads" => [ "Generate leads", "Collect quality leads and convert them into customers." ],
    "grow_followers" => [ "Grow followers", "Increase your audience size across social platforms." ],
    "boost_engagement" => [ "Boost engagement", "Get more likes, comments and shares on your content." ],
    "brand_awareness" => [ "Brand awareness", "Make more people aware of your brand." ],
    "website_visits" => [ "Website visits", "Drive more traffic to your website." ]
  }.freeze

  enum :goal, GOALS.index_by(&:itself), validate: true

  validates :goal, uniqueness: { scope: :workspace_id }

  def label = LABELS.fetch(goal).first
  def summary = LABELS.fetch(goal).last
end
