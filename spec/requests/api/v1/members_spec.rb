require "rails_helper"

RSpec.describe "API v1 members", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in(user) }
  let(:group) { create(:group) }

  describe "adding one" do
    it "adds a member and points at the occasion" do
      post api_v1_occasion_members_path(group), params: { name: "Aki" }, headers: bearer(token), as: :json

      member = group.members.last
      expect(response).to have_http_status(:created)
      expect(response.location).to eq(api_v1_occasion_url(group))
      expect(response.parsed_body).to eq(
        "id" => member.id, "name" => "Aki", "claimed" => false, "mine" => false, "removable" => true
      )
    end

    it "claims the new member for you when asked" do
      post api_v1_occasion_members_path(group), params: { name: "Luis", claim: true }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("claimed" => true, "mine" => true)
      expect(user.groups).to eq([ group ])
    end

    it "adds nobody when you already have a member here and ask to claim another" do
      create(:member, group:).claim_by(user)

      post api_v1_occasion_members_path(group), params: { name: "Luis", claim: true }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:conflict)
      expect(problem_code).to eq("already_claimed_here")
      expect(group.members.count).to eq(1)
    end

    it "refuses a name already used in the occasion" do
      create(:member, group:, name: "Aki")

      post api_v1_occasion_members_path(group), params: { name: "aki" }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["name"]).to match([ { "code" => "taken", "message" => a_kind_of(String) } ])
    end

    it "limits each user to 30 new members a minute" do
      30.times { |n| post api_v1_occasion_members_path(group), params: { name: "M#{n}" }, headers: bearer(token), as: :json }

      post api_v1_occasion_members_path(group), params: { name: "One more" }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "removing one" do
    it "removes a member who isn't in any expense" do
      member = create(:member, group:)

      delete api_v1_occasion_member_path(group, member), headers: bearer(token)

      expect(response).to have_http_status(:no_content)
      expect(group.members).to be_empty
    end

    it "keeps a member who is in an expense" do
      expense = create(:expense, group:)

      delete api_v1_occasion_member_path(group, expense.payer), headers: bearer(token)

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to include("code" => "member_in_use", "detail" => "支払いに関わっているメンバーは削除できません")
      expect(group.members.count).to eq(1)
    end

    it "is a 404 for a member of another occasion" do
      someone_else = create(:member)

      delete api_v1_occasion_member_path(group, someone_else), headers: bearer(token)

      expect(response).to have_http_status(:not_found)
      expect(Member.exists?(someone_else.id)).to be(true)
    end
  end
end
