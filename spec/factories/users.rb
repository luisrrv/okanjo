FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password" }

    # Signed up through LINE: no email, no password (ADR 0024).
    trait :line_only do
      email_address { nil }
      password { nil }
      sequence(:line_user_id) { |n| "U#{n.to_s.rjust(32, '0')}" }
    end
  end
end
