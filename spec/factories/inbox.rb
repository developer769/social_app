FactoryBot.define do
  factory :conversation do
    workspace
    social_account { association :social_account, workspace: workspace }
    provider { social_account.provider }
    kind { "comment" }
    sequence(:external_id) { |n| "thread-#{n}" }
    participant_name { "Meera Joshi" }
    participant_handle { "@meera" }
    preview { "Do you deliver to Vaishali Nagar?" }
    last_message_at { 1.hour.ago }
  end

  factory :message do
    conversation
    direction { "inbound" }
    body { "Do you deliver to Vaishali Nagar?" }
    sent_at { 1.hour.ago }
  end

  factory :saved_reply do
    workspace
    sequence(:title) { |n| "Delivery areas #{n}" }
    body { "Yes! We deliver across Jaipur. Orders before 4 PM go out the same day." }
  end
end
