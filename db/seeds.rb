# Demo data: the five-person night out used throughout the design docs (ADR 0013).
# Idempotent, so db:seed can run repeatedly.
#
# Local only: bin/docker-entrypoint runs db:prepare, which seeds a freshly created
# production database. A demo occasion doesn't belong there.
return unless Rails.env.local?

night_out = Group.find_or_create_by!(name: "飲み会")

aki, ben, chie, dai, emi = %w[Aki Ben Chie Dai Emi].map do |name|
  night_out.members.find_or_create_by!(name: name)
end

[
  { description: "1次会", payer: aki, amount: 20_000, members: [ aki, ben, chie, dai, emi ] },
  { description: "2次会", payer: ben, amount: 9_000, members: [ ben, chie, dai ] },
  { description: "タクシー", payer: dai, amount: 3_000, members: [ chie, dai ] }
].each do |attributes|
  night_out.expenses.find_or_create_by!(description: attributes[:description]) do |expense|
    expense.assign_attributes(attributes)
  end
end
