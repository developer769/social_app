class Workspace < ApplicationRecord
  ONBOARDING_STEPS = %w[business_setup catalog connections analysis health plan completed].freeze

  # Who the workspace belongs to. It changes what the product calls things
  # rather than what it can do -- both types get the same features -- so the
  # only thing that hangs off it is language.
  ACCOUNT_TYPES = %w[business influencer].freeze

  belongs_to :owner_user, class_name: "User"

  has_one :brand_profile, dependent: :destroy
  has_many :brand_goals, dependent: :destroy
  has_many :brand_tones, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :social_accounts, dependent: :destroy
  has_many :brand_analyses, dependent: :destroy
  has_many :social_health_scores, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :media_assets, dependent: :destroy
  has_many :creative_requests, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_one :posting_preference, dependent: :destroy
  has_one :brand_kit, dependent: :destroy
  has_many :notification_preferences, dependent: :destroy

  has_many :workspace_memberships, dependent: :destroy
  has_many :members, through: :workspace_memberships, source: :user
  has_many :ad_campaigns, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :saved_replies, dependent: :destroy
  has_many :audit_events, dependent: :nullify

  enum :onboarding_step, ONBOARDING_STEPS.index_by(&:itself), validate: true
  enum :account_type, ACCOUNT_TYPES.index_by(&:itself), prefix: :account, validate: true

  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase }

  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9-]{1,62}\z/ }
  validates :currency, presence: true, length: { is: 3 }
  validates :timezone, presence: true, inclusion: { in: ->(_) { ActiveSupport::TimeZone::MAPPING.values } }
  validates :country_code, presence: true, length: { is: 2 }

  before_validation :assign_slug, on: :create

  def onboarding_completed?
    onboarding_completed_at.present?
  end

  # The workspace creator retains a small set of essential operations (billing,
  # ownership transfer, workspace deletion) until roles are defined. This is
  # provisional and is the only permission asymmetry in the system (spec 2).
  def owned_by?(user)
    owner_user_id == user&.id
  end

  # One place that answers "what does this workspace call itself", so a view
  # never has to branch on the type inline and no screen can drift out of step
  # with the others.
  def owner_noun = account_influencer? ? "creator" : "business"
  def name_label = account_influencer? ? "Creator name" : "Business name"
  def name_placeholder = account_influencer? ? "@anayabakes" : "Anaya Bakes"
  def setup_title = account_influencer? ? "Creator Setup" : "Business Setup"

  private

  def assign_slug
    return if slug.present?

    base = name.to_s.parameterize.presence || "workspace"
    base = base.first(56)
    candidate = base

    candidate = "#{base}-#{SecureRandom.alphanumeric(6).downcase}" while self.class.exists?(slug: candidate)

    self.slug = candidate
  end

end
