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

  # Three queries whatever the group size: members, expenses, and their participations
  # (preloaded, so share_amount and collected count them in memory). The rest is Ruby.
  def rows
    @rows ||= begin
      credited = Hash.new(0)
      owed = Hash.new(0)

      @group.expenses.includes(:participations).each do |expense|
        credited[expense.payer_id] += expense.collected
        expense.participations.each { |participation| owed[participation.member_id] += expense.share_amount }
      end

      @group.members.order(:id).map do |member|
        Row.new(member:, credited: credited[member.id], owed: owed[member.id])
      end
    end
  end

  def balances
    rows.to_h { |row| [ row.member, row.balance ] }
  end
end
