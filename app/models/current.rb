# Request-scoped state. Reset automatically between requests and jobs.
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :workspace, :membership, :ip_address, :user_agent

  def user
    session&.user
  end
end
