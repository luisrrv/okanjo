require "rails_helper"

RSpec.describe "API v1 my occasions", type: :request do
  it "lists the occasions where your account holds a member, most recently changed first" do
    user = create(:user)
    older = create(:group, name: "旅行")
    newer = create(:group, name: "飲み会")
    not_mine = create(:group)
    create(:member, group: older).claim_by(user)
    me_tonight = create(:member, group: newer)
    me_tonight.claim_by(user)
    create(:member, group: newer)
    create(:member, group: not_mine)
    older.update_column(:updated_at, 1.day.ago)

    get api_v1_me_occasions_path, headers: bearer(api_sign_in(user))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["occasions"].map { |occasion| occasion["token"] }).to eq([ newer.token, older.token ])
    expect(response.parsed_body["occasions"].first).to eq(
      "token" => newer.token,
      "name" => "飲み会",
      "my_member_id" => me_tonight.id,
      "member_count" => 2,
      "deletion_date" => newer.reload.deletion_date.iso8601,
      "updated_at" => newer.updated_at.iso8601
    )
  end
end
