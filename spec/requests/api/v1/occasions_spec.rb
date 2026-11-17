require "rails_helper"

RSpec.describe "API v1 occasions", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in(user) }

  describe "reading one" do
    it "returns the whole occasion, with shares, balances and the settlement worked out" do
      # The five-person night out from ADR 0013.
      group = create(:group, name: "飲み会")
      aki, ben, chie, dai, emi = %w[Aki Ben Chie Dai Emi].map { |name| create(:member, group:, name:) }
      aki.claim_by(user)
      first = create(:expense, group:, description: "1次会", payer: aki, amount: 20_000, members: [ aki, ben, chie, dai, emi ])
      second = create(:expense, group:, description: "2次会", payer: ben, amount: 9_000, members: [ ben, chie, dai ])
      taxi = create(:expense, group:, description: "タクシー", payer: dai, amount: 3_000, members: [ chie, dai ])
      first.update_column(:created_at, 3.minutes.ago)
      second.update_column(:created_at, 2.minutes.ago)
      group.reload

      get api_v1_occasion_path(group), headers: bearer(token)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "token" => group.token,
        "name" => "飲み会",
        "deletion_date" => group.deletion_date.iso8601,
        "updated_at" => group.updated_at.iso8601,
        "my_member_id" => aki.id,
        "members" => [
          { "id" => aki.id, "name" => "Aki", "claimed" => true, "mine" => true, "removable" => false },
          { "id" => ben.id, "name" => "Ben", "claimed" => false, "mine" => false, "removable" => false },
          { "id" => chie.id, "name" => "Chie", "claimed" => false, "mine" => false, "removable" => false },
          { "id" => dai.id, "name" => "Dai", "claimed" => false, "mine" => false, "removable" => false },
          { "id" => emi.id, "name" => "Emi", "claimed" => false, "mine" => false, "removable" => false }
        ],
        "expenses" => [
          { "id" => taxi.id, "description" => "タクシー", "amount" => 3_000, "payer_id" => dai.id,
            "member_ids" => [ chie.id, dai.id ], "share_amount" => 1_500, "collected" => 3_000, "odd_yen" => 0,
            "created_at" => taxi.created_at.iso8601 },
          { "id" => second.id, "description" => "2次会", "amount" => 9_000, "payer_id" => ben.id,
            "member_ids" => [ ben.id, chie.id, dai.id ], "share_amount" => 3_000, "collected" => 9_000, "odd_yen" => 0,
            "created_at" => second.reload.created_at.iso8601 },
          { "id" => first.id, "description" => "1次会", "amount" => 20_000, "payer_id" => aki.id,
            "member_ids" => [ aki.id, ben.id, chie.id, dai.id, emi.id ], "share_amount" => 4_000, "collected" => 20_000,
            "odd_yen" => 0, "created_at" => first.reload.created_at.iso8601 }
        ],
        "balances" => [
          { "member_id" => aki.id, "credited" => 20_000, "owed" => 4_000, "balance" => 16_000 },
          { "member_id" => ben.id, "credited" => 9_000, "owed" => 7_000, "balance" => 2_000 },
          { "member_id" => chie.id, "credited" => 0, "owed" => 8_500, "balance" => -8_500 },
          { "member_id" => dai.id, "credited" => 3_000, "owed" => 8_500, "balance" => -5_500 },
          { "member_id" => emi.id, "credited" => 0, "owed" => 4_000, "balance" => -4_000 }
        ],
        "settlement" => {
          "collector_id" => aki.id,
          "transfers" => [
            { "from_id" => chie.id, "to_id" => aki.id, "amount" => 8_500 },
            { "from_id" => dai.id, "to_id" => aki.id, "amount" => 5_500 },
            { "from_id" => emi.id, "to_id" => aki.id, "amount" => 4_000 },
            { "from_id" => aki.id, "to_id" => ben.id, "amount" => 2_000 }
          ]
        }
      )
    end

    it "shows the odd yen the payer keeps, and no settlement while nobody owes anything" do
      group = create(:group)
      aki, ben, chie = %w[Aki Ben Chie].map { |name| create(:member, group:, name:) }

      get api_v1_occasion_path(group), headers: bearer(token)
      expect(response.parsed_body["settlement"]).to eq("collector_id" => nil, "transfers" => [])
      expect(response.parsed_body["my_member_id"]).to be_nil

      create(:expense, group:, payer: aki, amount: 1_000, members: [ aki, ben, chie ])
      get api_v1_occasion_path(group), headers: bearer(token)
      expect(response.parsed_body["expenses"].first).to include("share_amount" => 334, "collected" => 1_002, "odd_yen" => 2)
    end

    it "is a 404 for an unknown token" do
      get api_v1_occasion_path("no-such-token"), headers: bearer(token)

      expect(response).to have_http_status(:not_found)
      expect(problem_code).to eq("not_found")
    end

    it "answers 304 Not Modified until the occasion changes" do
      group = create(:group)
      aki = create(:member, group:)

      get api_v1_occasion_path(group), headers: bearer(token)
      etag = response.headers["ETag"]
      get api_v1_occasion_path(group), headers: bearer(token).merge("If-None-Match" => etag)
      expect(response).to have_http_status(:not_modified)

      create(:expense, group:, payer: aki)
      get api_v1_occasion_path(group), headers: bearer(token).merge("If-None-Match" => etag)
      expect(response).to have_http_status(:ok)
    end

    it "gives each user their own ETag, since my_member_id and mine differ" do
      group = create(:group)

      get api_v1_occasion_path(group), headers: bearer(token)
      etag = response.headers["ETag"]
      get api_v1_occasion_path(group), headers: bearer(api_sign_in(create(:user))).merge("If-None-Match" => etag)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "creating one" do
    it "creates the occasion with its first member, claimed by you" do
      post api_v1_occasions_path, params: { name: "飲み会", member_name: "Luis" }, headers: bearer(token), as: :json

      group = Group.last
      expect(response).to have_http_status(:created)
      expect(response.location).to eq(api_v1_occasion_url(group))
      expect(response.parsed_body).to include(
        "token" => group.token, "name" => "飲み会", "my_member_id" => group.members.first.id,
        "updated_at" => group.reload.updated_at.iso8601
      )
      expect(response.parsed_body["members"]).to eq([
        { "id" => group.members.first.id, "name" => "Luis", "claimed" => true, "mine" => true, "removable" => true }
      ])
      expect(user.groups).to eq([ group ])
    end

    it "doesn't need a name" do
      post api_v1_occasions_path, params: { member_name: "Luis" }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to be_nil
    end

    it "lists what's wrong under the API's field names" do
      post api_v1_occasions_path, params: { name: "あ" * 51, member_name: "" }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("code" => "validation_failed", "detail" => "入力内容を確認してください")
      expect(response.parsed_body["errors"].keys).to contain_exactly("name", "member_name")
      expect(response.parsed_body["errors"]["name"]).to match([ { "code" => "too_long", "message" => a_string_including("50") } ])
      expect(response.parsed_body["errors"]["member_name"].first["code"]).to eq("blank")
      expect(Group.count).to eq(0)
    end

    it "is a bad request without a body" do
      post api_v1_occasions_path, params: {}, headers: bearer(token), as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "limits each user to 10 new occasions a minute" do
      10.times { post api_v1_occasions_path, params: { member_name: "Luis" }, headers: bearer(token), as: :json }

      post api_v1_occasions_path, params: { member_name: "Luis" }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("60")
    end
  end
end
