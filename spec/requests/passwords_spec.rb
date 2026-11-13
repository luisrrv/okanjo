require "rails_helper"

RSpec.describe "Password resets", type: :request do
  it "emails a reset link to a registered address" do
    user = create(:user)

    expect { post passwords_path, params: { email_address: user.email_address } }
      .to have_enqueued_mail(PasswordsMailer, :reset).with(user)
    expect(flash[:notice]).to eq("メールアドレスが登録されていれば、再設定用のリンクを送りました。")
  end

  it "gives the same answer for an unknown address, so it doesn't reveal who has an account" do
    expect { post passwords_path, params: { email_address: "nobody@example.com" } }
      .not_to have_enqueued_mail(PasswordsMailer, :reset)
    expect(flash[:notice]).to eq("メールアドレスが登録されていれば、再設定用のリンクを送りました。")
  end

  it "changes the password and logs out every device" do
    user = create(:user)
    user.sessions.create!

    put password_path(user.password_reset_token), params: { password: "new-password", password_confirmation: "new-password" }

    expect(response).to redirect_to(new_session_path)
    expect(user.reload.authenticate("new-password")).to be_truthy
    expect(user.sessions).to be_empty
  end

  it "keeps the password when the two entries differ" do
    user = create(:user)
    token = user.password_reset_token

    put password_path(token), params: { password: "new-password", password_confirmation: "other-password" }

    expect(response).to redirect_to(edit_password_path(token))
    expect(flash[:alert]).to eq("パスワード（確認）とパスワードの入力が一致しません")
    expect(user.reload.authenticate("password")).to be_truthy
  end

  it "sends you back to the form for an invalid or expired link" do
    get edit_password_path("not-a-token")

    expect(response).to redirect_to(new_password_path)
    expect(flash[:alert]).to eq("リンクが無効か、有効期限が切れています")
  end
end
