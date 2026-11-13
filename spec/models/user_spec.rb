require "rails_helper"

RSpec.describe User do
  it "stores the email address trimmed and in lower case" do
    user = create(:user, email_address: "  Aki@Example.COM ")

    expect(user.email_address).to eq("aki@example.com")
  end

  it "allows one account per email address, whatever the case" do
    create(:user, email_address: "aki@example.com")
    user = build(:user, email_address: "AKI@example.com")

    expect(user).not_to be_valid
    expect(user.errors.full_messages).to include("メールアドレスはすでに存在します")
  end

  it "rejects an email address without an @" do
    user = build(:user, email_address: "aki.example.com")

    expect(user).not_to be_valid
  end

  it "needs a password of at least 8 characters" do
    user = build(:user, password: "1234567")

    expect(user).not_to be_valid
    expect(user.errors.full_messages).to include("パスワードは8文字以上で入力してください")
  end

  it "keeps the password when other attributes change" do
    user = create(:user)

    expect(User.find(user.id).update(email_address: "new@example.com")).to be(true)
  end
end
