require "rails_helper"

# Every API endpoint but sign-in needs a bearer token (ADR 0023). /me is the simplest one.
RSpec.describe "API v1 authentication", type: :request do
  it "lets a valid token through" do
    user = create(:user, email_address: "luis@example.com")
    token = api_sign_in(user)

    get api_v1_me_path, headers: bearer(token)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("id" => user.id, "email_address" => "luis@example.com", "line_linked" => false)
  end

  it "asks for a bearer token when none is sent" do
    get api_v1_me_path

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["WWW-Authenticate"]).to eq('Bearer realm="warikan"')
    expect(response.parsed_body).to include("code" => "unauthorized", "detail" => "ログインが必要です")
  end

  it "flags a token that doesn't verify" do
    get api_v1_me_path, headers: bearer("not-a-token")

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["WWW-Authenticate"]).to eq('Bearer realm="warikan", error="invalid_token"')
  end

  it "rejects a token after 30 days" do
    token = api_sign_in(create(:user))

    travel 30.days + 1.second
    get api_v1_me_path, headers: bearer(token)

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a session id signed for another purpose" do
    user = create(:user)
    session = user.sessions.create!

    get api_v1_me_path, headers: bearer(session.signed_id)

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects every token once the password is reset" do
    user = create(:user)
    token = api_sign_in(user)

    patch password_path(user.password_reset_token), params: { password: "new-password", password_confirmation: "new-password" }
    get api_v1_me_path, headers: bearer(token)

    expect(response).to have_http_status(:unauthorized)
  end

  it "limits each user to 300 requests a minute across the API" do
    token = api_sign_in(create(:user))
    Rails.cache.clear # the sign-in above counted against this IP, not the user

    300.times { get api_v1_me_path, headers: bearer(token) }
    get api_v1_me_path, headers: bearer(token)

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to eq("60")
  end
end
