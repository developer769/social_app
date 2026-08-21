FactoryBot.define do
  factory :creative_request do
    workspace
    post { association :post, workspace: workspace }
    status { "generating" }
    media_format { "image" }
    variant_count { 3 }
    provider { "mock" }

    # Rows up front, exactly as the real command does, so specs about progress
    # exercise the same shape production does.
    trait :with_outputs do
      after(:create) do |request|
        request.variant_count.times { |i| create(:creative_output, creative_request: request, position: i) }
      end
    end
  end

  factory :creative_output do
    creative_request
    position { 0 }
    status { "pending" }

    trait :ready do
      status { "ready" }
      outcome { "generated" }
      media_asset { association :media_asset, workspace: creative_request.workspace }
      finished_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      outcome { "refused" }
      error_message { "The generator would not make this one" }
      finished_at { Time.current }
    end
  end
end
