require "rails_helper"

RSpec.describe "Identities", type: :request do
  describe "GET /groups/:token" do
    it "asks who you are when this browser doesn't know" do
      group = create(:group)
      create(:member, group: group, name: "Aki")

      get group_path(group)

      expect(response.body).to include("あなたの名前を選んでください")
    end

    it "adds an opened occasion to your recent list" do
      group = create(:group, name: "共有されたイベント")
      create(:member, group: group)

      get group_path(group)
      get root_path

      expect(response.body).to include("共有されたイベント")
    end
  end

  describe "POST /groups/:token/identity" do
    it "remembers which member you are" do
      group = create(:group)
      aki = create(:member, group: group, name: "Aki")

      post group_identity_path(group), params: { member_id: aki.id }
      follow_redirect!

      expect(response.body).to include("あなた：Akiさん")
      expect(response.body).not_to include("あなたの名前を選んでください")
    end

    it "is not found for a member of another occasion" do
      group = create(:group)

      post group_identity_path(group), params: { member_id: create(:member).id }

      expect(response).to have_http_status(:not_found)
    end

    it "forgets you once your member is removed" do
      group = create(:group)
      create(:member, group: group, name: "Aki")
      ben = create(:member, group: group, name: "Ben")
      post group_identity_path(group), params: { member_id: ben.id }

      ben.destroy
      get group_path(group)

      expect(response.body).to include("あなたの名前を選んでください")
    end
  end

  describe "DELETE /groups/:token/identity" do
    it "clears who you are, but keeps the occasion in your recent list" do
      group = create(:group, name: "忘年会")
      aki = create(:member, group: group, name: "Aki")
      post group_identity_path(group), params: { member_id: aki.id }

      delete group_identity_path(group)
      follow_redirect!
      expect(response.body).to include("あなたの名前を選んでください")

      get root_path
      expect(response.body).to include("忘年会")
    end
  end
end
