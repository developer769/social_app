class ApplicationController < ActionController::Base
  include Authentication

  # Only modern browsers, per the Rails 8 default.
  allow_browser versions: :modern
end
