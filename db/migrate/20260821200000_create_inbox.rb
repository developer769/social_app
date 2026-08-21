class CreateInbox < ActiveRecord::Migration[8.1]
  def change
    # One thread of conversation with one person on one platform.
    #
    # Kept per social account rather than per workspace, because the same
    # customer messaging your Instagram and your Facebook Page is two
    # conversations to the platforms and cannot be honestly merged into one.
    create_table :conversations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :social_account, null: false, foreign_key: true
      t.references :post, foreign_key: true

      t.string :provider, null: false
      t.string :kind, null: false
      t.string :external_id, null: false

      t.string :participant_name
      t.string :participant_handle
      t.string :participant_external_id

      t.string :status, null: false, default: "open"
      t.text :preview
      t.string :permalink
      t.integer :rating

      t.datetime :last_message_at
      t.datetime :last_inbound_at
      t.datetime :closed_at
      t.references :closed_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    # The platform's own id is what makes syncing idempotent: pulling the same
    # thread twice must update it, never duplicate it.
    add_index :conversations, %i[social_account_id external_id], unique: true
    add_index :conversations, %i[workspace_id status last_message_at],
      order: { last_message_at: :desc }, name: "index_conversations_for_listing"

    add_check_constraint :conversations,
      "kind IN ('comment','direct_message','review')", name: "conversations_kind_is_known"
    add_check_constraint :conversations,
      "status IN ('open','closed')", name: "conversations_status_is_known"
    add_check_constraint :conversations,
      "rating IS NULL OR rating BETWEEN 1 AND 5", name: "conversations_rating_in_range"

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sent_by, foreign_key: { to_table: :users }

      t.string :external_id
      t.string :direction, null: false
      t.text :body, null: false

      t.string :author_name
      t.string :author_handle

      # Outbound only. An inbound message has already happened; an outbound one
      # can still fail on its way to the platform.
      t.string :delivery_status
      t.string :error_message
      t.datetime :sent_at

      t.timestamps
    end

    add_index :messages, %i[conversation_id sent_at]
    add_index :messages, %i[conversation_id external_id], unique: true,
      where: "external_id IS NOT NULL"

    add_check_constraint :messages,
      "direction IN ('inbound','outbound')", name: "messages_direction_is_known"
    add_check_constraint :messages,
      "delivery_status IS NULL OR delivery_status IN ('pending','sending','sent','failed')",
      name: "messages_delivery_status_is_known"
    add_check_constraint :messages,
      "direction <> 'outbound' OR delivery_status IS NOT NULL",
      name: "messages_outbound_has_delivery_status"

    # Answers a shop owner writes once and uses often.
    #
    # Useful before any inbox connects: while Prachar cannot reply for you, it
    # can still hold the answer you always give about delivery areas or opening
    # hours, ready to copy.
    create_table :saved_replies do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }

      t.string :title, null: false
      t.text :body, null: false
      t.integer :position, null: false, default: 0
      t.integer :times_used, null: false, default: 0

      t.timestamps
    end

    add_index :saved_replies, %i[workspace_id position]
    add_index :saved_replies, %i[workspace_id title], unique: true
  end
end
