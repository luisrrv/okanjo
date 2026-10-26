require "rails_helper"

RSpec.describe Group, type: :model do
  describe "token" do
    it "is generated on create" do
      group = create(:group)

      expect(group.token).to be_present
    end

    it "is unique per group" do
      first = create(:group)
      second = create(:group)

      expect(first.token).not_to eq(second.token)
    end

    it "is enforced unique by the database" do
      first = create(:group)
      second = create(:group)

      expect { second.update_column(:token, first.token) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "name" do
    it "is optional" do
      expect(build(:group, name: nil)).to be_valid
    end

    it "is at most 50 characters" do
      expect(build(:group, name: "忘" * 50)).to be_valid
      expect(build(:group, name: "忘" * 51)).not_to be_valid
    end

    it "is stripped, and stored as nil when blank" do
      expect(build(:group, name: "  忘年会  ").name).to eq("忘年会")
      expect(build(:group, name: "   ").name).to be_nil
    end
  end
end
