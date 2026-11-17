require "rails_helper"

RSpec.describe "API v1 claims", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in(user) }
  let(:group) { create(:group) }

  describe "claiming" do
    it "links the member to your account" do
      member = create(:member, group:, name: "Aki")

      put api_v1_occasion_member_claim_path(group, member), headers: bearer(token)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "id" => member.id, "name" => "Aki", "claimed" => true, "mine" => true, "removable" => true
      )
      expect(member.reload.user).to eq(user)
    end

    it "is a no-op for a member you already hold" do
      member = create(:member, group:)
      member.claim_by(user)

      put api_v1_occasion_member_claim_path(group, member), headers: bearer(token)

      expect(response).to have_http_status(:ok)
    end

    it "refuses a member another account holds" do
      member = create(:member, group:)
      member.claim_by(create(:user))

      put api_v1_occasion_member_claim_path(group, member), headers: bearer(token)

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to include("code" => "claimed_by_other", "detail" => "このメンバーは別のアカウントと連携済みです")
    end

    it "refuses a second member in the same occasion" do
      create(:member, group:).claim_by(user)
      other = create(:member, group:)

      put api_v1_occasion_member_claim_path(group, other), headers: bearer(token)

      expect(response).to have_http_status(:conflict)
      expect(problem_code).to eq("already_claimed_here")
      expect(other.reload.user).to be_nil
    end
  end

  describe "releasing" do
    it "unlinks your member" do
      member = create(:member, group:)
      member.claim_by(user)

      delete api_v1_occasion_member_claim_path(group, member), headers: bearer(token)

      expect(response).to have_http_status(:no_content)
      expect(member.reload.user).to be_nil
    end

    it "is a 404 for a member you don't hold, without saying who does" do
      member = create(:member, group:)
      member.claim_by(create(:user))

      delete api_v1_occasion_member_claim_path(group, member), headers: bearer(token)

      expect(response).to have_http_status(:not_found)
      expect(member.reload.user).not_to be_nil
    end
  end
end
