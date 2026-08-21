module Settings
  class HubController < BaseController
    def show
      @entries = SettingsMenu.entries
    end
  end
end
