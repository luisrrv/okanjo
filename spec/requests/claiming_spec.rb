require "rails_helper"

# Linking members to accounts (ADR 0022, docs/specs/accounts.md).
RSpec.describe "Claiming members", type: :request do
  describe "choosing who you are while logged in" do
    it "links the member to your account" do
      user = create(:user)
      aki = create(:member, name: "Aki")
      sign_in_as user

      post group_identity_path(aki.group), params: { member_id: aki.id }

      expect(aki.reload.user).to eq(user)
      expect(flash[:notice]).to eq("Akiさんとして表示しています")
    end

    it "refuses a member another account holds" do
      aki = create(:member, name: "Aki", user: create(:user))
      sign_in_as create(:user)

      post group_identity_path(aki.group), params: { member_id: aki.id }

      expect(flash[:alert]).to eq("このメンバーは別のアカウントと連携済みです")
      follow_redirect!
      expect(response.body).to include("ご自身の名前を選んでください")
    end

    it "releases your member when you say it isn't you" do
      user = create(:user)
      aki = create(:member, user: user)
      sign_in_as user

      delete group_identity_path(aki.group)

      expect(aki.reload.user).to be_nil
    end
  end

  it "knows who you are from your account on a browser that has never seen the occasion" do
    user = create(:user)
    aki = create(:member, name: "Aki", user: user)
    sign_in_as user

    get group_path(aki.group)

    expect(response.body).to include("あなた：Akiさん")
  end

  it "links the first member when you create an occasion while logged in" do
    user = create(:user)
    sign_in_as user

    post groups_path, params: { group: { members_attributes: { "0" => { name: "Aki" } } } }

    expect(user.members.pluck(:name)).to eq([ "Aki" ])
  end

  describe "logging in" do
    it "links the members this browser already remembers" do
      aki = create(:member)
      post group_identity_path(aki.group), params: { member_id: aki.id }
      user = create(:user)

      sign_in_as user

      expect(aki.reload.user).to eq(user)
    end

    it "skips a remembered member another account holds" do
      holder = create(:user)
      aki = create(:member, user: holder)
      post group_identity_path(aki.group), params: { member_id: aki.id }

      sign_in_as create(:user)

      expect(response).to redirect_to(root_url)
      expect(aki.reload.user).to eq(holder)
    end
  end

  it "links remembered members when you sign up" do
    aki = create(:member)
    post group_identity_path(aki.group), params: { member_id: aki.id }

    post registration_path, params: { user: { email_address: "aki@example.com", password: "password", password_confirmation: "password" } }

    expect(aki.reload.user.email_address).to eq("aki@example.com")
  end

  describe "the member banner" do
    it "marks a member linked to another account, without a button for you" do
      group = create(:group)
      create(:member, group: group, name: "Aki", user: create(:user))
      sign_in_as create(:user)

      get group_path(group)

      expect(response.body).to include("連携済み")
      expect(response.body).not_to match(/<button[^>]*>\s*Aki/)
    end

    it "still lets a logged-out visitor choose a linked member" do
      group = create(:group)
      create(:member, group: group, name: "Aki", user: create(:user))

      get group_path(group)

      expect(response.body).to include("連携済み")
      expect(response.body).to match(/<button[^>]*>\s*Aki/)
    end
  end

  describe "the home page" do
    it "lists your account's occasions first, without repeating them under recent" do
      user = create(:user)
      mine = create(:member, user: user, group: create(:group, name: "温泉旅行")).group
      other = create(:member, group: create(:group, name: "花見")).group
      get group_path(mine)
      get group_path(other)
      sign_in_as user

      get root_path

      expect(response.body).to include("自分の割り勘", "最近開いたイベント")
      expect(response.body.scan("温泉旅行").size).to eq(1)
      expect(response.body.index("温泉旅行")).to be < response.body.index("花見")
    end
  end
end
