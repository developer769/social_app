# Every business-owned record belongs to a workspace and is never queried
# without one (spec 7).
module WorkspaceOwned
  extend ActiveSupport::Concern

  included do
    belongs_to :workspace

    scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  end
end
