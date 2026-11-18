require "rails_helper"

RSpec.describe "The LIFF app", type: :request do
  # LINE's in-app browser, as it identifies itself on iOS and Android.
  LINE_IOS = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 " \
             "(KHTML, like Gecko) Mobile/15E148 Safari Line/15.10.0"
  LINE_ANDROID = "Mozilla/5.0 (Linux; Android 15; Pixel 8 Build/AP3A.241005.015; wv) AppleWebKit/537.36 " \
                 "(KHTML, like Gecko) Version/4.0 Chrome/138.0.7204.63 Mobile Safari/537.36 Line/15.10.0/IAB"

  before { stub_const("LiffController::PAGE", file_fixture("liff_show.html")) }

  it "serves the built page, revalidated on every launch" do
    get "/liff", params: { total: 4500, people: 3, "liff.state" => "/" }, headers: { "User-Agent" => LINE_IOS }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.headers["Cache-Control"]).to eq("no-cache")
    expect(response.body).to include('src="/liff/assets/index-test.js"')
  end

  it "lets LINE's in-app browser open an occasion on the website" do
    group = create(:group)

    [ LINE_IOS, LINE_ANDROID ].each do |user_agent|
      get group_path(group), headers: { "User-Agent" => user_agent }

      expect(response).to have_http_status(:ok), "#{user_agent} got #{response.status}"
    end
  end
end
