require "rails_helper"

RSpec.describe "Sessions", type: :request do
  def log_in(email_address:, password: "password")
    post session_path, params: { email_address:, password: }
  end

  it "logs you in and takes you home" do
    user = create(:user)

    log_in(email_address: user.email_address)

    expect(response).to redirect_to(root_url)
    expect(user.sessions.count).to eq(1)
  end

  it "says the email or password is wrong, without saying which" do
    user = create(:user)

    log_in(email_address: user.email_address, password: "wrong-password")

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq("メールアドレスかパスワードが正しくありません")
  end

  it "logs you out and forgets who you were in each occasion" do
    user = create(:user)
    group = create(:group)
    aki = create(:member, group: group)
    post group_identity_path(group), params: { member_id: aki.id }
    log_in(email_address: user.email_address)

    delete session_path

    expect(response).to redirect_to(root_path)
    expect(user.sessions.count).to eq(0)
    expect(cookies[:members]).to be_blank
  end

  it "limits each IP to 10 attempts in 3 minutes" do
    10.times { log_in(email_address: "nobody@example.com") }
    log_in(email_address: "nobody@example.com")

    expect(flash[:alert]).to eq("しばらくしてからもう一度お試しください")
  end
end
