require "rails_helper"

RSpec.describe BalanceSheet do
  it "is all zeros for an occasion with no expenses" do
    group = create(:group)
    create_list(:member, 2, group: group)

    rows = BalanceSheet.new(group).rows

    expect(rows.map { |row| [ row.credited, row.owed, row.balance ] }).to eq([ [ 0, 0, 0 ], [ 0, 0, 0 ] ])
  end

  it "credits the payer with what's collected, including the odd yen (ADR 0008)" do
    group = create(:group)
    aki, ben, chie = create_list(:member, 3, group: group)
    create(:expense, group: group, payer: aki, members: [ aki, ben, chie ], amount: 1000)

    balances = BalanceSheet.new(group).balances

    expect(balances).to eq(aki => 668, ben => -334, chie => -334)
  end

  it "credits a payer who is left out of the split (ADR 0015)" do
    group = create(:group)
    dai = create(:member, group: group)
    drinkers = create_list(:member, 3, group: group)
    create(:expense, group: group, payer: dai, members: drinkers, amount: 8000)

    balances = BalanceSheet.new(group).balances

    expect(balances.values).to eq([ 8001, -2667, -2667, -2667 ])
  end

  it "adds up the seeded night out" do
    group = create(:group)
    aki, ben, chie, dai, emi = %w[Aki Ben Chie Dai Emi].map { |name| create(:member, group: group, name: name) }
    create(:expense, group: group, payer: aki, amount: 20_000, members: [ aki, ben, chie, dai, emi ])
    create(:expense, group: group, payer: ben, amount: 9_000, members: [ ben, chie, dai ])
    create(:expense, group: group, payer: dai, amount: 3_000, members: [ chie, dai ])

    rows = BalanceSheet.new(group).rows

    expect(rows.map { |row| [ row.member.name, row.credited, row.owed, row.balance ] }).to eq([
      [ "Aki", 20_000, 4_000, 16_000 ],
      [ "Ben", 9_000, 7_000, 2_000 ],
      [ "Chie", 0, 8_500, -8_500 ],
      [ "Dai", 3_000, 8_500, -5_500 ],
      [ "Emi", 0, 4_000, -4_000 ]
    ])
  end

  it "always sums to zero across random occasions (ADR 0008)" do
    random = Random.new(2026)

    25.times do
      group = create(:group)
      members = create_list(:member, random.rand(1..8), group: group)
      random.rand(1..10).times do
        create(:expense, group: group, payer: members.sample(random: random),
                         members: members.sample(random.rand(1..members.size), random: random),
                         amount: random.rand(1..50_000))
      end

      expect(BalanceSheet.new(group).balances.values.sum).to eq(0)
    end
  end
end
