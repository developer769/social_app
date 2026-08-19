module Gallery
  class TemplatesController < ApplicationController
    include WorkspaceScoping

    def index
      @search = TemplateSearch.new(
        workspace: current_workspace,
        format: params[:format],
        category: params[:category],
        query: params[:q],
        page: params[:page]
      )
    end

    def show
      @template = Template.published.find_by!(slug: params[:slug])
      @compatible = compatible_accounts
      @incompatible = current_workspace.social_accounts.connected - @compatible
    end

    private

    # Which of THIS workspace's accounts could actually carry this style, read
    # from provider capabilities rather than the template's own platform list
    # (spec 30).
    def compatible_accounts
      current_workspace.social_accounts.connected.select do |account|
        @template.publishable_on?(account.provider)
      end
    end
  end
end
