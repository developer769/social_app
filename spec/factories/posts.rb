FactoryBot.define do
  factory :post do
    workspace
    status { "draft" }
    caption { "Indulge in layers of rich chocolate and silky ganache." }
    hashtags { %w[AnayaBakes Chocolate] }
  end

  factory :post_target do
    post
    social_account
  end

  factory :social_account do
    workspace
    provider { "instagram" }
    sequence(:external_account_id) { |n| "ext-#{n}" }
    username { "anaya.bakes" }
    connection_status { "connected" }
    permission_status { "granted" }
  end

  factory :media_asset do
    workspace
    kind { "image" }
    origin { "upload" }
    content_type { "image/jpeg" }

    after(:build) do |asset|
      asset.file.attach(
        io: File.open(Rails.root.join("db/seeds/templates/photo-01.jpg")),
        filename: "photo.jpg", content_type: "image/jpeg"
      )
    end

    trait :video do
      kind { "video" }
      content_type { "video/mp4" }

      after(:build) do |asset|
        asset.file.attach(io: StringIO.new("fake"), filename: "clip.mp4", content_type: "video/mp4")
      end
    end
  end
end
