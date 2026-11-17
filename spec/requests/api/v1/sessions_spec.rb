require "rails_helper"

RSpec.describe "API v1 sessions", type: :request do
  it "trades an email and password for a token that expires in 30 days" do
    freeze_time
    user = create(:user, email_address: "luis@example.com")

    post api_v1_session_path, params: { email_address: "luis@example.com", password: "password" }, as: :json

    expect(response).to have_http_status(:created)
    expect(response.location).to eq(api_v1_me_url)
    expect(response.parsed_body).to match(
      "token" => a_kind_of(String),
      "expires_at" => 30.days.from_now.iso8601,
      "user" => { "id" => user.id, "email_address" => "luis@example.com" }
    )
    expect(user.sessions.count).to eq(1)
  end

  it "answers a wrong password with a problem that doesn't say which field was wrong" do
    user = create(:user)

    post api_v1_session_path, params: { email_address: user.email_address, password: "wrong" }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.media_type).to eq("application/problem+json")
    expect(response.parsed_body).to eq(
      "type" => "https://warikan.lrod.dev/api/problems/invalid_credentials",
      "title" => "Invalid credentials",
      "status" => 401,
      "detail" => "メールアドレスかパスワードが正しくありません",
      "code" => "invalid_credentials"
    )
  end

  it "answers a missing password with a bad request" do
    post api_v1_session_path, params: { email_address: "luis@example.com" }, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(problem_code).to eq("bad_request")
  end

  it "answers malformed JSON with a bad request" do
    post api_v1_session_path, params: '{"email_address": ', headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(problem_code).to eq("bad_request")
  end

  it "limits each IP to 10 sign-ins in 3 minutes, and says when to retry" do
    10.times { post api_v1_session_path, params: { email_address: "nobody@example.com", password: "x" }, as: :json }

    post api_v1_session_path, params: { email_address: "nobody@example.com", password: "x" }, as: :json

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to eq("180")
    expect(problem_code).to eq("rate_limited")
  end

  it "cancels the token on sign-out" do
    token = api_sign_in(create(:user))

    delete api_v1_session_path, headers: bearer(token)
    expect(response).to have_http_status(:no_content)

    delete api_v1_session_path, headers: bearer(token)
    expect(response).to have_http_status(:unauthorized)
  end
end
