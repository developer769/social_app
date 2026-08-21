module Publishing
  # Decides what happens to one post whose time has come.
  #
  # Either every target that can publish is handed to its own job, or -- when
  # nothing can reach a platform -- the post settles as a reminder and the owner
  # is told it is time to post it themselves. What must never happen is silence,
  # or a screen that says published when nothing was.
  class PublishPostJob < ApplicationJob
    queue_as :default

    def perform(post_id)
      post = Post.find_by(id: post_id)
      return if post.nil? || !post.publishing?

      results = Preflight.new(post).call

      # Blocked targets are settled here rather than being sent to a job that
      # would only discover the same thing, one provider call later.
      results.reject(&:publishable?).each do |result|
        result.target.mark_skipped!(reason: result.blocking.first&.message || "This platform cannot carry this post.")
      end

      publishable = results.select(&:publishable?)

      if publishable.empty?
        # Every target is settled, so this derives "reminded" and sends the
        # reminder. Going through Settle rather than setting the status here
        # keeps one transition point, and gets its atomic claim and its audit
        # entry for free.
        Settle.call(post: post)
      else
        publishable.each { |result| PublishTargetJob.perform_later(result.target.id) }
      end
    end
  end
end
