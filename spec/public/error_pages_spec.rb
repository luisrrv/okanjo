require "rails_helper"

# Production serves these straight from public/ without running the app, so they can't use
# the locale files (ADR 0018). This keeps them Japanese and linked back to the start page.
RSpec.describe "Static error pages" do
  {
    "400.html" => "リクエストを処理できませんでした",
    "404.html" => "ページが見つかりません",
    "406-unsupported-browser.html" => "お使いのブラウザには対応していません",
    "422.html" => "変更を受け付けられませんでした",
    "500.html" => "エラーが発生しました"
  }.each do |file, heading|
    it "serves #{file} in Japanese with a way back to the start page" do
      page = Rails.root.join("public", file).read

      expect(page).to include('<html lang="ja">', "<h1>#{heading}</h1>", 'href="/"')
    end
  end

  it "explains on the 404 page that occasions are deleted after 30 days (ADR 0016)" do
    expect(Rails.root.join("public/404.html").read).to include("30日")
  end
end
