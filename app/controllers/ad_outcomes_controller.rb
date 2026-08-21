# Recording what a campaign actually brought in.
#
# The owner's own figures, kept apart from anything a platform reported. This
# is the only revenue most Indian small businesses will ever have: the order
# arrives on WhatsApp and the money arrives by UPI, and no platform sees either.
class AdOutcomesController < ApplicationController
  include WorkspaceScoping

  before_action :set_campaign
  before_action :set_outcome, only: %i[destroy]

  def new
    @outcome = @campaign.ad_outcomes.new(occurred_on: Date.current, currency: @campaign.currency)
  end

  def create
    @outcome = AdOutcome.new(outcome_params)
    @outcome.ad_campaign = @campaign
    @outcome.recorded_by = current_user
    @outcome.currency = @campaign.currency
    @outcome.errors.add(:revenue, "must be an amount, like 4500") if @revenue_unreadable

    if @outcome.errors.empty? && @outcome.save
      AuditEvent.record!(action: "ad_outcome.recorded", workspace: current_workspace,
                         actor_user: current_user, auditable: @campaign,
                         metadata: { orders: @outcome.orders, revenue_minor: @outcome.revenue_minor })
      redirect_to workspace_ads_path(workspace_slug: current_workspace.slug), notice: "Recorded."
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    @outcome.destroy!
    redirect_to workspace_ads_path(workspace_slug: current_workspace.slug), notice: "Removed."
  end

  private

  # Found through the workspace, so another tenant's campaign is simply absent.
  def set_campaign
    @campaign = current_workspace.ad_campaigns.find(params[:ad_campaign_id])
  end

  def set_outcome = @outcome = @campaign.ad_outcomes.find(params[:id])

  # Rupees in, minor units stored. Money is never a float, and the form asks in
  # the unit a shopkeeper actually thinks in.
  def outcome_params
    permitted = params.require(:ad_outcome).permit(:occurred_on, :orders, :revenue, :note)
    rupees = permitted.delete(:revenue)

    permitted.to_h.symbolize_keys.merge(revenue_minor: minor_units_for(rupees)).compact_blank
  end

  # Somebody will type "4,500" or "rs 4500" or leave it blank. None of those
  # should be a 500, and none of them should quietly become a different number.
  def minor_units_for(rupees)
    return if rupees.blank?

    cleaned = rupees.to_s.gsub(/[,\s₹]|rs\.?/i, "")
    return @revenue_unreadable = true unless cleaned.match?(/\A\d+(\.\d{1,2})?\z/)

    Money.from_major(cleaned, currency: @campaign.currency)&.minor_units
  end
end
