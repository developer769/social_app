class AddAccountTypeToWorkspaces < ActiveRecord::Migration[8.1]
  # Whether this workspace belongs to a business or to a creator.
  #
  # It is asked at sign-up rather than inferred later because it changes what
  # the product calls things from the very first screen -- a creator does not
  # have a "business name", and being asked for one is the moment somebody
  # decides this tool was not built for them.
  #
  # Defaulted rather than nullable: every workspace that already exists was
  # created through the business path, so "business" is the true answer for all
  # of them, not a placeholder.
  def change
    add_column :workspaces, :account_type, :string, null: false, default: "business"

    # A check constraint rather than a Rails-only enum, matching how
    # onboarding_step and currency are already guarded on this table: the
    # database refuses a value the application would not have written.
    add_check_constraint :workspaces,
      "account_type IN ('business', 'influencer')",
      name: "workspaces_account_type_is_known"
  end
end
