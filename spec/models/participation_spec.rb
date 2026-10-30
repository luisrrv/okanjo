require "rails_helper"

RSpec.describe Participation, type: :model do
  it "allows a member only once per expense" do
    expense = create(:expense)

    duplicate = expense.participations.build(member: expense.payer)

    expect(duplicate).not_to be_valid
  end

  it "is enforced unique by the database" do
    expense = create(:expense)

    expect { Participation.insert!({ expense_id: expense.id, member_id: expense.payer_id }) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end
