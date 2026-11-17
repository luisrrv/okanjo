# Shares round up and the payer keeps the odd yen (ADR 0008).
json.id expense.id
json.description expense.description
json.amount expense.amount
json.payer_id expense.payer_id
json.member_ids expense.participations.map(&:member_id).sort
json.share_amount expense.share_amount
json.collected expense.collected
json.odd_yen expense.odd_yen
json.created_at expense.created_at.iso8601
