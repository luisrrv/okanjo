# The whole occasion in one response (ADR 0023, D4). Money is computed here on the server by
# the same objects the website uses; the client never recomputes it (ADR 0008, 0009, 0013).
my_member = @members.find { |member| member.user_id == Current.user.id }

json.token @group.token
json.name @group.name
json.deletion_date @group.deletion_date
json.updated_at @group.updated_at.iso8601
json.my_member_id my_member&.id

json.members @members do |member|
  json.partial! "api/v1/members/member", member:, removable: @removable_ids.include?(member.id)
end

json.expenses @expenses do |expense|
  json.partial! "api/v1/expenses/expense", expense:
end

json.balances @balance_sheet.rows do |row|
  json.member_id row.member.id
  json.credited row.credited
  json.owed row.owed
  json.balance row.balance
end

json.settlement do
  json.collector_id @settlement.collector&.id
  json.transfers @settlement.transfers do |transfer|
    json.from_id transfer.from.id
    json.to_id transfer.to.id
    json.amount transfer.amount
  end
end
