FactoryBot.define do
  factory :workspace_membership do
    workspace
    user
    invitation_status { "accepted" }
    membership_status { "active" }
    accepted_at { Time.current }

    trait :pending do
      user { nil }
      sequence(:invitation_email) { |n| "teammate#{n}@anayabakes.test" }
      invitation_status { "pending" }
      accepted_at { nil }
      invited_at { Time.current }
      expires_at { WorkspaceMembership::INVITATION_TTL.from_now }
    end

    trait :removed do
      membership_status { "removed" }
      removed_at { Time.current }
    end
  end
end
