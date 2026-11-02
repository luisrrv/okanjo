# Plain Ruby, no table: what each member of an occasion is credited with, owes, and
# their balance (ADR 0009). Lives in app/models because a Rails model is a domain
# object, with or without a database table.
class BalanceSheet
  Row = Data.define(:member, :credited, :owed) do
    def balance
      credited - owed
    end
  end

  def initialize(group)
    @group = group
  end

  def rows
    @rows ||= @group.members.order(:id).map do |member|
      credited = member.paid_expenses.sum(&:collected)
      owed = member.participations.sum { |participation| participation.expense.share_amount }
      Row.new(member:, credited:, owed:)
    end
  end

  def balances
    rows.to_h { |row| [ row.member, row.balance ] }
  end
end
