class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    # citext gives case-insensitive uniqueness for email without every query
    # having to remember to downcase.
    enable_extension "citext"
  end
end
