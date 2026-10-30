FactoryBot.define do
  factory :member do
    group
    sequence(:name) { |n| "Member #{n}" }
  end
end
