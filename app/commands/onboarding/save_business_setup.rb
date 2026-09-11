module Onboarding
  # Saves step 1 and advances onboarding progress.
  #
  # Touches Workspace, BrandProfile, BrandGoal and BrandTone, so it runs in a
  # transaction: a half-saved brand would leave content generation reading
  # inconsistent context.
  class SaveBusinessSetup < ApplicationCommand
    STEP = "business_setup"

    def initialize(workspace:, dto:, actor:, advance: true)
      @workspace = workspace
      @dto = dto
      @actor = actor
      @advance = advance
    end

    def call
      profile = @workspace.brand_profile || @workspace.build_brand_profile

      ActiveRecord::Base.transaction do
        apply_workspace_attributes
        apply_profile_attributes(profile)

        @workspace.save!
        profile.save!

        replace_goals
        replace_tones
        advance_progress if @advance

        AuditEvent.record!(
          action: "onboarding.business_setup_saved",
          workspace: @workspace,
          actor_user: @actor,
          auditable: profile,
          metadata: { goals: @dto.goals, tones: @dto.tones }
        )
      end

      Result.success(profile)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record)
    end

    private

    def apply_workspace_attributes
      @workspace.name = @dto.business_name if @dto.business_name.present?
      @workspace.timezone = @dto.timezone if @dto.timezone.present?
    end

    def apply_profile_attributes(profile)
      profile.assign_attributes(
        category: @dto.category,
        business_type: @dto.business_type,
        contact_email: @dto.contact_email,
        phone: @dto.phone,
        website_url: @dto.website_url,
        city: @dto.city,
        about: @dto.about
      )

      # Uploading a replacement logo is not image editing: the previous file is
      # swapped, never modified (spec 2).
      profile.logo.attach(@dto.logo) if @dto.logo.present?
    end

    def replace_goals
      @workspace.brand_goals.where.not(goal: @dto.goals).destroy_all
      existing = @workspace.brand_goals.pluck(:goal)
      (@dto.goals - existing).each { |goal| @workspace.brand_goals.create!(goal: goal) }
    end

    def replace_tones
      @workspace.brand_tones.where.not(tone: @dto.tones).destroy_all
      existing = @workspace.brand_tones.pluck(:tone)
      (@dto.tones - existing).each { |tone| @workspace.brand_tones.create!(tone: tone) }
    end

    def advance_progress
      next_step = OnboardingFlow.next_key(STEP, @workspace.account_type)
      @workspace.update!(onboarding_step: OnboardingFlow.furthest(@workspace.onboarding_step, next_step, @workspace.account_type))
    end
  end
end
