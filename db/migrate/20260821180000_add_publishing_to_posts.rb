class AddPublishingToPosts < ActiveRecord::Migration[8.1]
  def up
    # How a post is meant to go out.
    #
    # "automatic" means Prachar publishes it. "reminder" means Prachar cannot --
    # because no adapter for that platform is connected -- and says so at the
    # moment of scheduling rather than failing silently at 11am. The mode is
    # decided when the post is scheduled and stored, so changing what is
    # connected later cannot retroactively change what the owner agreed to.
    add_column :posts, :publish_mode, :string, null: false, default: "automatic"
    add_column :posts, :reminded_at, :datetime
    add_column :posts, :publish_started_at, :datetime

    add_check_constraint :posts, "publish_mode IN ('automatic','reminder')",
      name: "posts_publish_mode_is_known"

    # "reminded" is a real outcome and not a failure: nothing went wrong, and
    # nothing was published either. Calling it failed would be a lie in the
    # alarming direction.
    remove_check_constraint :posts, name: "posts_status_is_known"
    add_check_constraint :posts,
      "status IN ('draft','awaiting_approval','approved','scheduled','publishing'," \
      "'published','partially_published','reminded','failed','cancelled')",
      name: "posts_status_is_known"

    # Finding what is due runs every minute forever, so it must not scan.
    add_index :posts, %i[status scheduled_at],
      where: "status = 'scheduled'", name: "index_posts_due_for_publishing"

    # What a provider said, kept per attempt rather than only the last one, so a
    # post that failed twice and then worked can still be explained.
    add_column :post_targets, :last_attempt_at, :datetime
    add_column :post_targets, :next_attempt_at, :datetime
    add_column :post_targets, :provider_response, :jsonb, null: false, default: {}
  end

  def down
    remove_index :posts, name: "index_posts_due_for_publishing"
    remove_check_constraint :posts, name: "posts_publish_mode_is_known"
    remove_check_constraint :posts, name: "posts_status_is_known"
    add_check_constraint :posts,
      "status IN ('draft','awaiting_approval','approved','scheduled','publishing'," \
      "'published','failed','cancelled')",
      name: "posts_status_is_known"
    remove_column :posts, :publish_mode
    remove_column :posts, :reminded_at
    remove_column :posts, :publish_started_at
    remove_column :post_targets, :last_attempt_at
    remove_column :post_targets, :next_attempt_at
    remove_column :post_targets, :provider_response
  end
end
