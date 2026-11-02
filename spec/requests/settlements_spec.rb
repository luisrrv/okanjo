require "rails_helper"

RSpec.describe "The settle-up section", type: :request do
  it "shows each balance and the transfers through the collector" do
    group = create(:group)
    aki, ben, chie, dai, emi = %w[Aki Ben Chie Dai Emi].map { |name| create(:member, group: group, name: name) }
    create(:expense, group: group, payer: aki, amount: 20_000, members: [ aki, ben, chie, dai, emi ])
    create(:expense, group: group, payer: ben, amount: 9_000, members: [ ben, chie, dai ])
    create(:expense, group: group, payer: dai, amount: 3_000, members: [ chie, dai ])

    get group_path(group)

    expect(response.body).to include("立て替え 20,000円 · 負担 4,000円", "+16,000円", "−8,500円")
    expect(response.body).to include("Akiさんがまとめて精算します")
    expect(response.body).to include("Chieさん → Akiさん", "8,500円", "Akiさん → Benさん", "2,000円")
  end

  it "says there's nothing to settle before any expenses" do
    group = create(:group)
    create(:member, group: group)

    get group_path(group)

    expect(response.body).to include("精算はありません")
  end
end
