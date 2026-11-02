require "rails_helper"

RSpec.describe "Groups", type: :request do
  def create_group(name: "忘年会", your_name: "Aki")
    post groups_path, params: { group: { name: name, members_attributes: { "0" => { name: your_name } } } }
  end

  describe "GET /" do
    it "shows the form to start an occasion" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("割り勘をはじめる")
    end
  end

  describe "POST /groups" do
    it "creates the occasion with you as its first member" do
      expect { create_group }.to change(Group, :count).by(1).and change(Member, :count).by(1)

      group = Group.last
      expect(group.members.first.name).to eq("Aki")
      expect(response).to redirect_to(group_path(group.token))
    end

    it "remembers you, so the occasion shows up in your recent list" do
      create_group(name: "箱根旅行")

      get root_path

      expect(response.body).to include("最近開いたイベント", "箱根旅行", "1人")
    end

    it "allows a blank occasion name" do
      expect { create_group(name: "") }.to change(Group, :count).by(1)
    end

    it "re-renders with a Japanese error when your name is blank" do
      expect { create_group(your_name: "") }.not_to change(Group, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("あなたの名前を入力してください")
    end

    it "limits each IP to 10 new occasions a minute" do
      10.times { create_group }
      expect(response).to have_http_status(:redirect)

      create_group

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "GET /groups/:token" do
    it "shows the occasion by its token" do
      group = create(:group, name: "忘年会")

      get group_path(group)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("忘年会", "に削除されます", group_url(group))
    end

    it "uses the token in URLs, never the id" do
      group = create(:group)

      expect(group_path(group)).to eq("/groups/#{group.token}")
    end

    it "is not found for an unknown token" do
      get group_path("no-such-token")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "recent occasions" do
    it "forgets occasions that have been deleted" do
      create_group(name: "消えるイベント")
      Group.last.destroy

      get root_path

      expect(response.body).not_to include("消えるイベント", "最近開いたイベント")
    end
  end
end
