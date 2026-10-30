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
      expect(duplicate.errors[:name]).to include("has already been taken")
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

  describe "touching the group" do
    it "moves the group's updated_at when a member is added" do
      group = create(:group, updated_at: 1.day.ago)

      create(:member, group: group)

      expect(group.reload.updated_at).to be > 1.minute.ago
    end
  end
end
