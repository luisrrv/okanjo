require "rails_helper"

# The generator makes every controller require a login. Occasions must never need one
# (ADR 0022), so this visits each core page signed out.
RSpec.describe "Signed-out access to occasions", type: :request do
  it "opens every page of an occasion without asking to log in" do
    group = create(:group)
    expense = create(:expense, group: group)

    [ root_path, group_path(group), new_group_expense_path(group),
      edit_group_expense_path(group, expense), group_receipt_path(group) ].each do |path|
      get path

      expect(response).to have_http_status(:ok), "#{path} returned #{response.status}"
    end
  end

  it "shows a log-in link in the header" do
    get root_path

    expect(response.body).to include("ログイン")
  end
end
