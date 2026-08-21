module Settings
  class NotificationsController < BaseController
    def show
      @preference = preference
    end

    def update
      @preference = preference

      if @preference.update(preference_params)
        redirect_to workspace_settings_notifications_path(**slug), notice: "Saved."
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    # Per person, so this is always the signed-in user's own row.
    def preference = NotificationPreference.for(workspace: current_workspace, user: current_user)

    def preference_params
      params.expect(notification_preference: NotificationPreference::CHANNELS.keys.map(&:to_sym))
    end
  end
end
