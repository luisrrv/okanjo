require "rails_helper"

# LINE's answer is stubbed: LineIdToken has its own spec.
RSpec.describe "API v1 LINE sign-in", type: :request do
  def line_says(id_token, line_user_id)
    allow(LineIdToken).to receive(:verify).with(id_token).and_return(line_user_id)
  end

  def sign_in_with_line(id_token, **email_account)
    post api_v1_line_session_path, params: { id_token:, **email_account }, as: :json
  end

  describe "signing in" do
    it "creates a LINE-only account the first time, then signs into the same one" do
      line_says("token", "U1")

      sign_in_with_line("token")
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["user"]).to match("id" => a_kind_of(Integer), "email_address" => nil, "line_linked" => true)

      sign_in_with_line("token")
      expect(User.where(line_user_id: "U1").count).to eq(1)
      expect(User.find_by(line_user_id: "U1").sessions.count).to eq(2)
    end

    it "gives a token that works on the rest of the API" do
      line_says("token", "U1")
      sign_in_with_line("token")

      get api_v1_me_path, headers: bearer(response.parsed_body["token"])

      expect(response.parsed_body).to include("line_linked" => true)
    end

    it "is a 401 when LINE rejects the token" do
      allow(LineIdToken).to receive(:verify).and_raise(LineIdToken::Invalid)

      sign_in_with_line("expired")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include("code" => "invalid_line_token")
      expect(User.count).to eq(0)
    end

    it "is a 503 with Retry-After when LINE can't be reached" do
      allow(LineIdToken).to receive(:verify).and_raise(LineIdToken::Unavailable)

      sign_in_with_line("token")

      expect(response).to have_http_status(:service_unavailable)
      expect(response.headers["Retry-After"]).to eq("30")
      expect(problem_code).to eq("line_unavailable")
    end

    it "is a bad request without an ID token" do
      post api_v1_line_session_path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "linking an email account" do
    it "links LINE to the email account and signs into it" do
      user = create(:user, email_address: "aki@example.com")
      line_says("token", "U1")

      sign_in_with_line("token", email_address: "aki@example.com", password: "password")

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["user"]).to include("id" => user.id, "line_linked" => true)
      expect(user.reload.line_user_id).to eq("U1")
    end

    it "merges the LINE-only account, so its occasions follow, and its old token stops working" do
      line_says("token", "U1")
      sign_in_with_line("token")
      old_token = response.parsed_body["token"]
      line_user = User.find_by(line_user_id: "U1")
      member = create(:member)
      member.claim_by(line_user)
      user = create(:user, email_address: "aki@example.com")

      sign_in_with_line("token", email_address: "aki@example.com", password: "password")

      expect(response).to have_http_status(:created)
      expect(member.reload.user).to eq(user)
      expect(User.exists?(line_user.id)).to be(false)
      get api_v1_me_path, headers: bearer(old_token)
      expect(response).to have_http_status(:unauthorized)
    end

    it "just signs in when they're already linked" do
      user = create(:user, email_address: "aki@example.com", line_user_id: "U1")
      line_says("token", "U1")

      sign_in_with_line("token", email_address: "aki@example.com", password: "password")

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["user"]["id"]).to eq(user.id)
    end

    it "refuses an email account linked to a different LINE account" do
      create(:user, email_address: "aki@example.com", line_user_id: "U2")
      line_says("token", "U1")

      sign_in_with_line("token", email_address: "aki@example.com", password: "password")

      expect(response).to have_http_status(:conflict)
      expect(problem_code).to eq("email_account_linked_elsewhere")
    end

    it "refuses a LINE account linked to a different email account" do
      create(:user, email_address: "ben@example.com", line_user_id: "U1")
      user = create(:user, email_address: "aki@example.com")
      line_says("token", "U1")

      sign_in_with_line("token", email_address: "aki@example.com", password: "password")

      expect(response).to have_http_status(:conflict)
      expect(problem_code).to eq("line_linked_elsewhere")
      expect(user.reload.line_user_id).to be_nil
    end

    it "links nothing with the wrong password" do
      user = create(:user, email_address: "aki@example.com")
      line_says("token", "U1")

      sign_in_with_line("token", email_address: "aki@example.com", password: "wrong")

      expect(response).to have_http_status(:unauthorized)
      expect(problem_code).to eq("invalid_credentials")
      expect(user.reload.line_user_id).to be_nil
    end
  end
end
