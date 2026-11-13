require "rails_helper"

RSpec.describe Member, type: :model do
  describe "name" do
    it "is required" do
      expect(build(:member, name: "  ")).not_to be_valid
    end

    it "is at most 50 characters" do
      expect(build(:member, name: "ゆ" * 50)).to be_valid
      expect(build(:member, name: "ゆ" * 51)).not_to be_valid
    end

    it "is stripped" do
      expect(build(:member, name: "  Yuki ").name).to eq("Yuki")
    end

    it "is unique within a group, ignoring case" do
      group = create(:group)
      create(:member, group: group, name: "Yuki")

      duplicate = build(:member, group: group, name: "yuki")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages).to include("名前が同じメンバーがすでにいます")
    end

    it "can repeat across groups" do
      create(:member, name: "Yuki")

      expect(build(:member, name: "Yuki")).to be_valid
    end

    it "is enforced unique by the database, ignoring case" do
      group = create(:group)
      create(:member, group: group, name: "Yuki")
      other = create(:member, group: group, name: "Ken")

      expect { other.update_column(:name, "YUKI") }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "deletion" do
    it "is rejected for a member who paid for something, even outside the split" do
      group = create(:group)
      dai = create(:member, group: group)
      create(:expense, group: group, payer: dai, members: [ create(:member, group: group) ])

      expect(dai.destroy).to be(false)
      expect(dai.errors[:base]).not_to be_empty
    end

    it "is rejected for a member in a split" do
      expense = create(:expense)
      guest = create(:member, group: expense.group)
      expense.members << guest

      expect(guest.destroy).to be(false)
    end

    it "lists only members with no payments or splits as removable" do
      group = create(:group)
      payer = create(:member, group: group)
      guest = create(:member, group: group)
      idle = create(:member, group: group)
      create(:expense, group: group, payer: payer, members: [ guest ])

      expect(group.members.removable).to contain_exactly(idle)
    end

    it "is allowed for a member with no expenses" do
      member = create(:member)

      expect { member.destroy }.to change(Member, :count).by(-1)
    end
  end

  describe "touching the group" do
    it "moves the group's updated_at when a member is added" do
      group = create(:group, updated_at: 1.day.ago)

      create(:member, group: group)

      expect(group.reload.updated_at).to be > 1.minute.ago
    end
  end

  describe "#claim_by" do
    it "links an unlinked member to the account" do
      member = create(:member)
      user = create(:user)

      expect(member.claim_by(user)).to be(true)
      expect(member.reload.user).to eq(user)
    end

    it "is fine to claim your own member again" do
      user = create(:user)
      member = create(:member, user: user)

      expect(member.claim_by(user)).to be(true)
    end

    it "refuses a member another account holds" do
      member = create(:member, user: create(:user))

      expect(member.claim_by(create(:user))).to be(false)
      expect(member.errors.full_messages).to eq([ "このメンバーは別のアカウントと連携済みです" ])
    end

    it "refuses a second member for the same account in one occasion" do
      user = create(:user)
      group = create(:group)
      create(:member, group: group, user: user)
      other = create(:member, group: group)

      expect(other.claim_by(user)).to be(false)
      expect(other.errors.full_messages).to eq([ "アカウントはこのイベントの別のメンバーと連携済みです" ])
    end

    it "lets one account have a member in each of several occasions" do
      user = create(:user)

      expect([ create(:member), create(:member) ].map { |member| member.claim_by(user) }).to eq([ true, true ])
    end
  end

  describe "#release_by" do
    it "unlinks the member for the account holding it" do
      user = create(:user)
      member = create(:member, user: user)

      member.release_by(user)

      expect(member.reload.user).to be_nil
    end

    it "does nothing for any other account" do
      holder = create(:user)
      member = create(:member, user: holder)

      expect(member.release_by(create(:user))).to be(false)
      expect(member.reload.user).to eq(holder)
    end
  end

  it "is unlinked, not deleted, when its account is deleted" do
    member = create(:member, user: create(:user))

    member.user.destroy

    expect(member.reload.user).to be_nil
  end

  it "has a database guarantee of one member per account in each occasion" do
    user = create(:user)
    group = create(:group)
    create(:member, group: group, user: user)
    other = create(:member, group: group)

    expect { other.update_column(:user_id, user.id) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
