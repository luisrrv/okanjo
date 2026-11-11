require "rails_helper"

RSpec.describe "Receipts", type: :request do
  it "lists every expense with who was in its split, the total, and the settle-up plan" do
    group = create(:group, name: "飲み会")
    aki, ben, chie, dai, emi = %w[Aki Ben Chie Dai Emi].map { |name| create(:member, group: group, name: name) }
    create(:expense, group: group, payer: aki, description: "1次会", amount: 20_000, members: [ aki, ben, chie, dai, emi ])
    create(:expense, group: group, payer: ben, description: "2次会", amount: 9_000, members: [ ben, chie, dai ])
    create(:expense, group: group, payer: dai, description: "タクシー", amount: 3_000, members: [ chie, dai ])

    get group_receipt_path(group)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("割り勘の精算明細", "飲み会", "発行日：", "印刷／PDFで保存")
    expect(response.body).to include("割り勘の対象：Benさん、Chieさん、Daiさん（1人あたり 3,000円）")
    expect(response.body).to include("合計", "32,000円")
    expect(response.body).to include("Akiさんが代表して精算します", "Chieさん → Akiさん")
  end

  it "says there are no payments for an occasion without expenses" do
    group = create(:group)
    create(:member, group: group)

    get group_receipt_path(group)

    expect(response.body).to include("支払いはありません", "精算する金額はありません")
  end

  it "is not found for an unknown occasion" do
    get group_receipt_path("no-such-token")

    expect(response).to have_http_status(:not_found)
  end

  it "is linked from the occasion page" do
    group = create(:group)

    get group_path(group)

    expect(response.body).to include("精算明細を印刷", group_receipt_path(group))
  end
end
