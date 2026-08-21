module Settings
  class PostingPreferencesController < BaseController
    def show
      @preference = preference
    end

    def update
      @preference = preference

      if @preference.update(preference_params)
        AuditEvent.record!(action: "posting_preferences.updated", workspace: current_workspace,
                           actor_user: current_user, auditable: @preference)
        redirect_to workspace_settings_posting_preferences_path(**slug), notice: "Saved."
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def preference
      current_workspace.posting_preference || current_workspace.create_posting_preference!
    end

    def preference_params
      permitted = params.expect(
        posting_preference: [ :brand_voice, :caption_style, :hashtag_style, :emoji_level,
                              :default_call_to_action, :posts_per_week, :preferred_time,
                              :append_hashtags_as_first_comment, :default_first_comment,
                              :default_link_url, { preferred_days: [] } ]
      )

      permitted[:preferred_days] = Array(permitted[:preferred_days]).compact_blank.map(&:to_i)
      permitted[:brand_keywords] = split_list(params.dig(:posting_preference, :brand_keywords_text))
      permitted[:avoid_terms] = split_list(params.dig(:posting_preference, :avoid_terms_text))
      permitted[:default_link_url] = CatalogUrl.normalise(permitted[:default_link_url])
      permitted
    end

    def split_list(value) = value.to_s.split(",").map(&:strip).compact_blank.uniq
  end
end
