class AddPostReminderNotification < ActiveRecord::Migration[8.1]
  def change
    # Defaults to true: this one exists because Prachar cannot publish for you
    # yet, so switching it off means the scheduled moment passes in silence.
    add_column :notification_preferences, :email_post_reminder, :boolean, null: false, default: true
  end
end
