module Analysis
  # Maps each task key to the analyzer that answers it.
  module Registry
    ANALYZERS = {
      "profile_health" => ProfileHealth,
      "top_content" => TopContent,
      "posting_frequency" => PostingFrequency,
      "audience_engagement" => AudienceEngagement,
      "best_posting_times" => BestPostingTimes,
      "content_categories" => ContentCategories,
      "brand_voice" => BrandVoice
    }.freeze

    module_function

    def for(task_key) = ANALYZERS.fetch(task_key.to_s)
    def keys = ANALYZERS.keys
  end
end
