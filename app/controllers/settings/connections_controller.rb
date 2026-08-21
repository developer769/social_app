module Settings
  class ConnectionsController < BaseController
    def show
      @accounts_by_provider = current_workspace.social_accounts.index_by(&:provider)
      @providers = SocialProvider::Catalog.all
    end
  end
end
