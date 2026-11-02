require "rails_helper"

RSpec.describe "Members", type: :request do
  describe "POST /groups/:token/members" do
    it "adds a member to the occasion" do
      group = create(:group)

      expect { post group_members_path(group), params: { member: { name: "Ben" } } }
        .to change(group.members, :count).by(1)

      expect(response).to redirect_to(group_path(group))
      follow_redirect!
      expect(response.body).to include("Benさんを追加しました")
    end

    it "re-renders the occasion with a Japanese error for a duplicate name" do
      group = create(:group)
      create(:member, group: group, name: "Yuki")

      post group_members_path(group), params: { member: { name: "yuki" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("名前はすでに存在します")
    end

    it "remembers you when you add yourself from the banner" do
      group = create(:group)

      post group_members_path(group), params: { member: { name: "Chie" }, me: "1" }
      follow_redirect!

      expect(response.body).to include("あなた：Chieさん")
    end

    it "is not found for an unknown occasion" do
      post group_members_path("no-such-token"), params: { member: { name: "Ben" } }

      expect(response).to have_http_status(:not_found)
    end

    it "limits each IP to 30 new members a minute" do
      group = create(:group)

      30.times { |n| post group_members_path(group), params: { member: { name: "Member #{n}" } } }
      post group_members_path(group), params: { member: { name: "One too many" } }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "DELETE /groups/:token/members/:id" do
    it "removes a member with no expenses" do
      member = create(:member)

      expect { delete group_member_path(member.group, member) }.to change(Member, :count).by(-1)
    end

    it "refuses to remove a member who paid for something" do
      expense = create(:expense)

      expect { delete group_member_path(expense.group, expense.payer) }.not_to change(Member, :count)

      follow_redirect!
      expect(response.body).to include("支払いや割り勘に含まれているため削除できません")
    end

    it "is not found for a member of another occasion" do
      group = create(:group)
      outsider = create(:member)

      delete group_member_path(group, outsider)

      expect(response).to have_http_status(:not_found)
      expect(Member.exists?(outsider.id)).to be(true)
    end
  end
end
