class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  layout "authentication"

  def new
    @user = User.new
  end

  def create
    result = Onboarding::RegisterOwner.call(
      dto: Onboarding::RegisterOwnerDto.new(**registration_params.to_h.symbolize_keys),
      ip_address: request.remote_ip
    )

    if result.success?
      start_new_session_for(result.value.user)
      redirect_to workspace_root_path(workspace_slug: result.value.workspace.slug)
    else
      @user = result.error
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.expect(user: %i[name email password business_name])
  end
end
