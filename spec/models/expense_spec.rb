require "rails_helper"

RSpec.describe Expense, type: :model do
  # An expense of `amount` split between `ways` members of one group, paid by the first.
  def split(amount:, ways:)
    group = create(:group)
    members = create_list(:member, ways, group: group)
    create(:expense, group: group, payer: members.first, members: members, amount: amount)
  end

  describe "shares (ADR 0008)" do
    it "rounds each share up and the payer keeps the odd yen" do
      expense = split(amount: 1000, ways: 3)

      expect([ expense.share_amount, expense.collected, expense.odd_yen ]).to eq([ 334, 1002, 2 ])
    end

    it "has no odd yen when the amount divides evenly" do
      expense = split(amount: 1000, ways: 4)

      expect([ expense.share_amount, expense.collected, expense.odd_yen ]).to eq([ 250, 1000, 0 ])
    end

    it "charges the whole amount to a single member in the split" do
      expense = split(amount: 1000, ways: 1)

      expect([ expense.share_amount, expense.odd_yen ]).to eq([ 1000, 0 ])
    end

    it "handles amounts smaller than the number of members" do
      expense = split(amount: 1, ways: 3)

      expect([ expense.share_amount, expense.collected, expense.odd_yen ]).to eq([ 1, 3, 2 ])
    end

    it "works when the payer is left out of the split (ADR 0015)" do
      group = create(:group)
      dai = create(:member, group: group, name: "Dai")
      drinkers = create_list(:member, 3, group: group)

      expense = create(:expense, group: group, payer: dai, members: drinkers, amount: 8000)

      expect([ expense.share_amount, expense.collected, expense.odd_yen ]).to eq([ 2667, 8001, 1 ])
    end

    it "keeps the invariants for every amount from 1 to 1000 split 1 to 10 ways" do
      (1..10).each do |ways|
        group = create(:group)
        members = create_list(:member, ways, group: group)
        expense = build(:expense, group: group, payer: members.first, members: members)

        (1..1000).each do |amount|
          expense.amount = amount
          expect(expense.collected).to be >= amount
          expect(expense.odd_yen).to be < ways
        end
      end
    end
  end

  describe "validations" do
    it "requires a description" do
      expect(build(:expense, description: "   ")).not_to be_valid
    end

    it "limits the description to 100 characters" do
      expect(build(:expense, description: "会" * 100)).to be_valid
      expect(build(:expense, description: "会" * 101)).not_to be_valid
    end

    it "accepts whole yen from 1 to 2,000,000,000" do
      expect(build(:expense, amount: 1)).to be_valid
      expect(build(:expense, amount: 2_000_000_000)).to be_valid
    end

    it "rejects zero, negative, fractional and too-large amounts" do
      [ 0, -1, "1000.5", 2_000_000_001 ].each do |amount|
        expect(build(:expense, amount: amount)).not_to be_valid, "expected #{amount.inspect} to be invalid"
      end
    end

    it "needs at least one member in the split" do
      expect(build(:expense, members: [])).not_to be_valid
    end

    it "rejects a payer from another group" do
      outsider = create(:member)

      expect(build(:expense, payer: outsider)).not_to be_valid
    end

    it "rejects a member in the split from another group" do
      expense = build(:expense)
      expense.members << create(:member)

      expect(expense).not_to be_valid
    end

    it "keeps the split unchanged when an update empties it" do
      expense = split(amount: 1000, ways: 2)

      expect(expense.update(member_ids: [])).to be(false)
      expect(expense.reload.members.size).to eq(2)
    end
  end

  describe "the amount ceiling (spec D5)" do
    it "is needed because Rails raises above SQLite's 8-byte integer when skipping validations" do
      expense = create(:expense)

      expect { expense.update_column(:amount, 2**63) }.to raise_error(ActiveModel::RangeError)
    end

    it "turns that crash into a validation error" do
      expense = create(:expense)

      expect(expense.update(amount: 2**63)).to be(false)
      expect(expense.errors[:amount]).not_to be_empty
    end
  end

  describe "touching the group" do
    it "moves the group's updated_at when an expense is added" do
      group = create(:group)
      payer = create(:member, group: group)
      group.update_column(:updated_at, 1.day.ago)

      create(:expense, group: group, payer: payer)

      expect(group.reload.updated_at).to be > 1.minute.ago
    end

    it "moves the group's updated_at when only the split changes" do
      expense = split(amount: 1000, ways: 3)
      group = expense.group
      group.update_column(:updated_at, 1.day.ago)

      expense.update!(member_ids: expense.member_ids.first(2))

      expect(group.reload.updated_at).to be > 1.minute.ago
    end
  end
end
