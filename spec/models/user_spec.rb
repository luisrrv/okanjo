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

RSpec.describe User, "with LINE (ADR 0024)" do
  it "can be LINE-only, with no email or password" do
    user = build(:user, :line_only)

    expect(user).to be_valid
  end

  it "needs some way to sign in" do
    user = build(:user, email_address: nil, password: nil)

    expect(user).not_to be_valid
    expect(user.errors).to be_added(:email_address, :blank)
  end

  it "needs a password with an email, even with LINE" do
    user = build(:user, :line_only, email_address: "aki@example.com")

    expect(user).not_to be_valid
    expect(user.errors).to be_added(:password, :blank)
  end

  it "is held to the same rule by the database, past the validations" do
    user = create(:user, :line_only)

    expect { user.update_columns(line_user_id: nil) }.to raise_error(ActiveRecord::CheckViolation)
  end

  it "allows one account per LINE ID, enforced by the unique index" do
    create(:user, :line_only, line_user_id: "U1")

    expect { create(:user, :line_only, line_user_id: "U1") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "can unlink LINE only with an email and password to fall back on" do
    expect(build(:user, line_user_id: "U1").can_unlink_line?).to be(true)
    expect(build(:user, :line_only).can_unlink_line?).to be(false)
  end

  describe "merging a LINE-only account" do
    it "takes its claims and LINE ID, and deletes it with its sessions" do
      email_user = create(:user)
      line_user = create(:user, :line_only, line_user_id: "U1")
      line_user.sessions.create!
      trip = create(:group)
      aki = create(:member, group: trip)
      aki.claim_by(line_user)

      email_user.merge_line_account!(line_user)

      expect(email_user.reload.line_user_id).to eq("U1")
      expect(aki.reload.user).to eq(email_user)
      expect(User.exists?(line_user.id)).to be(false)
      expect(Session.where(user_id: line_user.id)).to be_empty
    end

    it "keeps this account's member where both held one in the same occasion" do
      email_user = create(:user)
      line_user = create(:user, :line_only)
      dinner = create(:group)
      mine = create(:member, group: dinner)
      theirs = create(:member, group: dinner)
      mine.claim_by(email_user)
      theirs.claim_by(line_user)

      email_user.merge_line_account!(line_user)

      expect(mine.reload.user).to eq(email_user)
      expect(theirs.reload.user).to be_nil
      expect(theirs.reload.group).to eq(dinner)
    end
  end
end
