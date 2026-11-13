require "rails_helper"

# Logging out clears this browser's memory of its occasions, so finding the occasion again
# after logging back in shows it came from the account, as it would on another device.
RSpec.describe "Accounts", type: :system do
  it "finds your occasion again after logging out and back in" do
    visit root_path
    click_on "ログイン"
    click_on "アカウントを作成"
    fill_in "メールアドレス", with: "aki@example.com"
    fill_in "パスワード", with: "password", match: :prefer_exact
    fill_in "パスワード（確認）", with: "password"
    click_on "作成する"
    expect(page).to have_content("アカウントを作成しました")

    fill_in "イベント名（任意）", with: "温泉旅行"
    fill_in "あなたの名前", with: "Aki"
    click_on "作成する"
    expect(page).to have_content("イベントを作成しました")

    click_on "ログアウト"
    expect(page).to have_link("ログイン")
    expect(page).to have_no_content("温泉旅行")

    click_on "ログイン"
    fill_in "メールアドレス", with: "aki@example.com"
    fill_in "パスワード", with: "password"
    within("form") { click_on "ログイン" }

    within("section", text: "自分の割り勘") { click_on "温泉旅行" }
    expect(page).to have_content("あなた：Akiさん")
  end
end
