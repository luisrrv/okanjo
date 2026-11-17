require "rails_helper"

RSpec.describe "API v1 expenses", type: :request do
  let(:token) { api_sign_in(create(:user)) }
  let(:group) { create(:group) }
  let(:aki) { create(:member, group:, name: "Aki") }
  let(:ben) { create(:member, group:, name: "Ben") }

  def add_expense(**body)
    post api_v1_occasion_expenses_path(group), params: body, headers: bearer(token), as: :json
  end

  describe "adding one" do
    it "adds an expense with its shares worked out" do
      add_expense(description: "1次会", amount: 1_000, payer_id: aki.id, member_ids: [ aki.id, ben.id ])

      expense = group.expenses.last
      expect(response).to have_http_status(:created)
      expect(response.location).to eq(api_v1_occasion_url(group))
      expect(response.parsed_body).to eq(
        "id" => expense.id, "description" => "1次会", "amount" => 1_000, "payer_id" => aki.id,
        "member_ids" => [ aki.id, ben.id ], "share_amount" => 500, "collected" => 1_000, "odd_yen" => 0,
        "created_at" => expense.created_at.iso8601
      )
    end

    it "lists what's wrong under the API's field names" do
      someone_else = create(:member)

      add_expense(description: "", amount: 0, payer_id: someone_else.id, member_ids: [])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].keys).to contain_exactly("description", "amount", "payer_id", "member_ids")
      expect(group.expenses).to be_empty
    end

    it "refuses an amount that isn't a whole number of yen, instead of rounding it" do
      add_expense(description: "1次会", amount: 1_000.5, payer_id: aki.id, member_ids: [ aki.id ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["amount"].first["code"]).to eq("not_an_integer")
    end

    it "refuses an amount above the ceiling" do
      add_expense(description: "1次会", amount: Expense::MAX_AMOUNT + 1, payer_id: aki.id, member_ids: [ aki.id ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]["amount"].first["code"]).to eq("less_than_or_equal_to")
    end

    it "accepts a whole number sent as a string, exactly" do
      add_expense(description: "1次会", amount: "1000", payer_id: aki.id, member_ids: [ aki.id ])

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["amount"]).to eq(1_000)
    end

    it "limits each user to 30 new expenses a minute" do
      30.times { add_expense(description: "x", amount: 100, payer_id: aki.id, member_ids: [ aki.id ]) }

      add_expense(description: "x", amount: 100, payer_id: aki.id, member_ids: [ aki.id ])

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "editing and deleting" do
    it "changes only the fields sent" do
      expense = create(:expense, group:, payer: aki, amount: 1_000, members: [ aki ])

      patch api_v1_occasion_expense_path(group, expense), params: { amount: 3_000, member_ids: [ aki.id, ben.id ] },
                                                         headers: bearer(token), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("amount" => 3_000, "member_ids" => [ aki.id, ben.id ], "share_amount" => 1_500,
                                              "description" => expense.description, "payer_id" => aki.id)
    end

    it "deletes an expense" do
      expense = create(:expense, group:)

      delete api_v1_occasion_expense_path(group, expense), headers: bearer(token)

      expect(response).to have_http_status(:no_content)
      expect(group.expenses).to be_empty
    end

    it "is a 404 for an expense in another occasion" do
      someone_elses = create(:expense)

      delete api_v1_occasion_expense_path(group, someone_elses), headers: bearer(token)

      expect(response).to have_http_status(:not_found)
      expect(Expense.exists?(someone_elses.id)).to be(true)
    end
  end
end
