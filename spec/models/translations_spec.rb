require "rails_helper"

# Error messages are built from these names, so a missing one would show an English
# fallback ("Description") inside a Japanese sentence (ADR 0018).
RSpec.describe "Japanese model and attribute names" do
  {
    Group => %i[name],
    Member => %i[name],
    Expense => %i[description amount payer members]
  }.each do |model, attributes|
    it "names #{model} and its validated attributes in Japanese" do
      names = [ model.model_name.human, *attributes.map { |attribute| model.human_attribute_name(attribute) } ]

      expect(names).to all(match(/\p{Han}|\p{Katakana}|\p{Hiragana}/))
    end
  end

  it "uses Japanese for Rails' own messages (rails-i18n)" do
    expense = build(:expense, description: "", amount: nil)
    expense.valid?

    expect(expense.errors.full_messages).to include("内容を入力してください", "金額を入力してください")
  end

  it "asks to choose, not enter, the payer and the members in the split" do
    expense = build(:expense, payer: nil, members: [])
    expense.valid?

    expect(expense.errors.full_messages).to include("支払った人を選択してください", "割り勘の対象メンバーを選択してください")
  end

  it "words each amount problem as the copy review asked (F9-F11)" do
    messages = [ "abc", 0, 2_000_000_001 ].map do |amount|
      expense = build(:expense, amount: amount)
      expense.valid?
      expense.errors.full_messages
    end

    expect(messages).to eq([
      [ "金額を数字で入力してください" ],
      [ "金額は1円以上で入力してください" ],
      [ "金額が上限（2,000,000,000円）を超えています" ]
    ])
  end

  it "formats long dates without leading zeros" do
    expect(I18n.l(Date.new(2026, 12, 2), format: :long)).to eq("2026年12月2日(水)")
  end

  it "translates the group-integrity errors" do
    expense = build(:expense, payer: create(:member))
    expense.valid?

    expect(expense.errors.full_messages).to include("支払った人がこのイベントのメンバーに含まれていません")
  end
end
