module Admin
  # The staff area.
  #
  # Inherits from ActionController::Base rather than ApplicationController so it
  # cannot accidentally pick up customer authentication, workspace scoping, or
  # anything else that assumes a tenant. The two areas share nothing.
  class BaseController < ActionController::Base
    include StaffAuthentication

    protect_from_forgery with: :exception
    allow_browser versions: :modern

    layout "admin"

    private

    def default_url_options = {}
  end
end
