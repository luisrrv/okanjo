require "rails_helper"

RSpec.describe Settlement do
  # Members with ids in join order; no database needed for the pure logic.
  def members(*names)
    names.map.with_index(1) { |name, id| build_stubbed(:member, id: id, name: name) }
  end

  def describe_transfers(settlement)
    settlement.transfers.map { |transfer| [ transfer.from.name, transfer.to.name, transfer.amount ] }
  end

  describe "#collector" do
    it "is the member with the largest positive balance" do
      aki, ben, chie = members("Aki", "Ben", "Chie")

      expect(Settlement.new(aki => 2_000, ben => 16_000, chie => -18_000).collector).to eq(ben)
    end

    it "goes to whoever joined first on a tie" do
      aki, ben, chie = members("Aki", "Ben", "Chie")

      expect(Settlement.new(aki => 500, ben => 500, chie => -1_000).collector).to eq(aki)
    end

    it "is nil when nobody is owed anything" do
      aki, ben = members("Aki", "Ben")

      expect(Settlement.new(aki => 0, ben => 0).collector).to be_nil
    end
  end

  describe "#transfers" do
    it "settles the seeded night out through Aki" do
      aki, ben, chie, dai, emi = members("Aki", "Ben", "Chie", "Dai", "Emi")
      settlement = Settlement.new(aki => 16_000, ben => 2_000, chie => -8_500, dai => -5_500, emi => -4_000)

      expect(describe_transfers(settlement)).to eq([
        [ "Chie", "Aki", 8_500 ],
        [ "Dai", "Aki", 5_500 ],
        [ "Emi", "Aki", 4_000 ],
        [ "Aki", "Ben", 2_000 ]
      ])
    end

    it "leaves out members who are already at zero" do
      aki, ben, chie = members("Aki", "Ben", "Chie")

      expect(describe_transfers(Settlement.new(aki => 1_000, ben => 0, chie => -1_000))).to eq([ [ "Chie", "Aki", 1_000 ] ])
    end

    it "is empty when everyone is at zero" do
      aki, ben = members("Aki", "Ben")

      expect(Settlement.new(aki => 0, ben => 0).transfers).to be_empty
    end
  end

  describe "invariants (ADR 0013)" do
    it "holds for random occasions" do
      random = Random.new(2026)

      25.times do
        group = create(:group)
        people = create_list(:member, random.rand(1..8), group: group)
        random.rand(1..10).times do
          create(:expense, group: group, payer: people.sample(random: random),
                           members: people.sample(random.rand(1..people.size), random: random),
                           amount: random.rand(1..50_000))
        end
        balances = BalanceSheet.new(group).balances
        settlement = Settlement.new(balances)

        after = balances.dup
        settlement.transfers.each do |transfer|
          after[transfer.from] += transfer.amount
          after[transfer.to] -= transfer.amount
        end

        expect(after.values).to all(eq(0))
        expect(settlement.transfers.size).to be <= [ people.size - 1, 0 ].max
        expect(settlement.transfers).to all(satisfy { |transfer| transfer.from != transfer.to && transfer.amount.positive? })
      end
    end
  end
end
