require "rails_helper"

RSpec.describe "Expenses", type: :request do
  def expense_params(payer:, members:, amount: 1000, description: "1次会")
    { expense: { description: description, amount: amount, payer_id: payer.id, member_ids: members.map(&:id) } }
  end

  describe "GET /groups/:token/expenses/new" do
    it "pre-fills a numbered label, you as the payer, and everyone in the split" do
      group = create(:group)
      aki = create(:member, group: group, name: "Aki")
      ben = create(:member, group: group, name: "Ben")
      create(:expense, group: group, payer: aki, members: [ aki ])
      post group_identity_path(group), params: { member_id: ben.id }

      get new_group_expense_path(group)

      expect(response.body).to include('value="お会計 2"')
      expect(response.body).to match(/<option selected="selected" value="#{ben.id}">Ben<\/option>/)
      expect(response.body.scan(/type="checkbox" value="\d+" checked="checked"/).size).to eq(2)
    end
  end

  describe "POST /groups/:token/expenses" do
    it "adds the expense and shows each share on the occasion page" do
      group = create(:group)
      members = create_list(:member, 3, group: group)

      expect { post group_expenses_path(group), params: expense_params(payer: members.first, members: members) }
        .to change(group.expenses, :count).by(1)

      follow_redirect!
      expect(response.body).to include("支払いを追加しました", "1人 334円 × 3人", "端数 2円")
    end

    it "labels a payer who is left out of the split" do
      group = create(:group)
      dai = create(:member, group: group, name: "Dai")
      drinkers = create_list(:member, 3, group: group)

      post group_expenses_path(group), params: expense_params(payer: dai, members: drinkers, amount: 8000)
      follow_redirect!

      expect(response.body).to include("1人 2,667円 × 3人", "支払い：Daiさん（割り勘の対象外）")
    end

    it "re-renders with a Japanese error when nobody is in the split" do
      group = create(:group)
      aki = create(:member, group: group)

      post group_expenses_path(group), params: { expense: { description: "x", amount: 1000, payer_id: aki.id, member_ids: [ "" ] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("割り勘するメンバーを選択してください")
    end

    it "rejects a payer from another occasion" do
      group = create(:group)
      aki = create(:member, group: group)

      post group_expenses_path(group), params: expense_params(payer: create(:member), members: [ aki ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("支払った人はこのイベントのメンバーではありません")
    end

    it "rejects a member in the split from another occasion" do
      group = create(:group)
      aki = create(:member, group: group)

      post group_expenses_path(group), params: expense_params(payer: aki, members: [ aki, create(:member) ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("割り勘するメンバーにこのイベント以外のメンバーが含まれています")
    end

    it "limits each IP to 30 new expenses a minute" do
      group = create(:group)
      aki = create(:member, group: group)

      31.times { post group_expenses_path(group), params: expense_params(payer: aki, members: [ aki ]) }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "PATCH /groups/:token/expenses/:id" do
    it "updates the expense" do
      expense = create(:expense, amount: 1000)

      patch group_expense_path(expense.group, expense),
            params: expense_params(payer: expense.payer, members: [ expense.payer ], amount: 1500)

      expect(expense.reload.amount).to eq(1500)
      expect(response).to redirect_to(group_path(expense.group))
    end

    it "keeps the expense unchanged when the update is invalid" do
      expense = create(:expense, amount: 1000)

      patch group_expense_path(expense.group, expense),
            params: expense_params(payer: expense.payer, members: [ expense.payer ], amount: 0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(expense.reload.amount).to eq(1000)
    end
  end

  describe "DELETE /groups/:token/expenses/:id" do
    it "deletes the expense" do
      expense = create(:expense)

      expect { delete group_expense_path(expense.group, expense) }.to change(Expense, :count).by(-1)
    end
  end

  describe "another occasion's expense" do
    it "is not found when editing, updating or deleting through this occasion" do
      group = create(:group)
      outsider = create(:expense)

      get edit_group_expense_path(group, outsider)
      expect(response).to have_http_status(:not_found)

      patch group_expense_path(group, outsider), params: { expense: { amount: 1 } }
      expect(response).to have_http_status(:not_found)

      delete group_expense_path(group, outsider)
      expect(response).to have_http_status(:not_found)
      expect(Expense.exists?(outsider.id)).to be(true)
    end
  end
end
