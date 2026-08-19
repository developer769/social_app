class TemplateFavourite < ApplicationRecord
  include WorkspaceOwned

  belongs_to :template
  belongs_to :user

  validates :template_id, uniqueness: { scope: :workspace_id }

  # Kept accurate by the command that creates and destroys these, so the
  # gallery can order by real interest rather than a guess.
  after_create_commit  { Template.where(id: template_id).update_counters(favourites_count: 1) }
  after_destroy_commit { Template.where(id: template_id).update_counters(favourites_count: -1) }
end
