require "rails_helper"

RSpec.describe PasswordsMailer do
  it "sends the reset link in Japanese, from the app's address" do
    user = create(:user, email_address: "aki@example.com")

    mail = PasswordsMailer.reset(user)

    expect(mail.subject).to eq("【割り勘】パスワードの再設定")
    expect(mail.to).to eq([ "aki@example.com" ])
    expect(mail.from).to eq([ "no-reply@warikan.lrod.dev" ])
    expect(mail.text_part.decoded).to include("有効期限は15分です", "/passwords/")
  end
end
