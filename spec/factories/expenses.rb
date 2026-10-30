FactoryBot.define do
  factory :expense do
    group
    payer { association :member, group: group }
    sequence(:description) { |n| "お会計 #{n}" }
    amount { 1000 }
    members { [ payer ] }
  end
end
