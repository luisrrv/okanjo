require "rails_helper"

RSpec.describe "API v1 unlinking LINE", type: :request do
  it "unlinks LINE from an account that can still sign in with email" do
    user = create(:user, line_user_id: "U1")

    delete api_v1_me_line_path, headers: bearer(api_sign_in(user))

    expect(response).to have_http_status(:no_content)
    expect(user.reload.line_user_id).to be_nil
  end

  it "refuses for a LINE-only account, which would have no way to sign in" do
    user = create(:user, :line_only)
    token = user.sessions.create!.api_token(expires_at: 1.day.from_now)

    delete api_v1_me_line_path, headers: bearer(token)

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body).to include("code" => "cannot_unlink", "detail" => "ログイン方法がなくなるため、連携を解除できません")
    expect(user.reload.line_user_id).not_to be_nil
  end

  it "is a 404 when LINE isn't linked" do
    delete api_v1_me_line_path, headers: bearer(api_sign_in(create(:user)))

    expect(response).to have_http_status(:not_found)
  end
end
