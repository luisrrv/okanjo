require "rails_helper"

RSpec.describe "Core flow", type: :system do
  # Dai doesn't drink but pays the ¥8,000 drinks tab for Aki, Ben and Chie (ADR 0015).
  def start_night_out_and_open_expense_form
    visit root_path
    fill_in "イベント名（任意）", with: "飲み会"
    fill_in "あなたの名前", with: "Dai"
    click_on "作成する"
    expect(page).to have_content("イベントを作成しました")

    %w[Aki Ben Chie].each do |name|
      within("#members") do
        fill_in "名前", with: name
        click_on "追加"
      end
      expect(page).to have_content("#{name}さんを追加しました")
    end

    within("#expenses") { click_on "追加" }
    fill_in "金額", with: "8000"
  end

  it "splits a bill among everyone but the payer after confirmation" do
    start_night_out_and_open_expense_form

    accept_confirm("Daiさんは割り勘に含まれません。Akiさん、Benさん、Chieさんで8,000円を割り勘し、1人2,667円になります。よろしいですか？") do
      uncheck "Dai"
    end
    click_on "保存する"

    expect(page).to have_content("支払いを追加しました")
    expect(page).to have_content("1人 2,667円 × 3人")
    expect(page).to have_content("支払い：Daiさん（割り勘の対象外）")
  end

  it "keeps the payer in the split when the confirmation is cancelled" do
    start_night_out_and_open_expense_form

    dismiss_confirm { uncheck "Dai" }
    expect(page).to have_checked_field("Dai")
    click_on "保存する"

    expect(page).to have_content("1人 2,000円 × 4人")
    expect(page).to have_content("支払い：Daiさん")
  end
end
