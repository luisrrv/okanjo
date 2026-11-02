# Plain Ruby, no table: who pays whom, all through a single collector (ADR 0013).
# Lives in app/models because a Rails model is a domain object, with or without a
# database table. Takes the balances from BalanceSheet, which sum to zero.
class Settlement
  Transfer = Data.define(:from, :to, :amount)

  def initialize(balances)
    @balances = balances
  end

  # The member with the largest positive balance; ties go to whoever joined first.
  # Nil when nobody is owed anything.
  def collector
    return @collector if defined?(@collector)

    @collector = @balances.select { |_member, balance| balance.positive? }
                          .min_by { |member, balance| [ -balance, member.id ] }&.first
  end

  # Payments to the collector first, then payments from the collector, each in join order.
  def transfers
    return [] unless collector

    paying, receiving = @balances.except(collector)
                                 .reject { |_member, balance| balance.zero? }
                                 .sort_by { |member, _balance| member.id }
                                 .partition { |_member, balance| balance.negative? }

    paying.map { |member, balance| Transfer.new(from: member, to: collector, amount: -balance) } +
      receiving.map { |member, balance| Transfer.new(from: collector, to: member, amount: balance) }
  end
end
