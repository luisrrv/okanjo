class Api::V1::ExpensesController < Api::V1::BaseController
  include Api::V1::OccasionScoped

  # The API's field names for the model's errors.
  FIELDS = { members: :member_ids, payer: :payer_id }.freeze

  # member_ids isn't an Expense attribute, so Rails wouldn't wrap it by default.
  wrap_parameters include: %i[description amount payer_id member_ids]
  api_rate_limit to: 30, within: 1.minute, only: :create, name: "expenses", by: -> { Current.user.id }

  before_action :set_expense, only: %i[update destroy]

  def create
    @expense = Expense.new(expense_params.merge(group: @group))

    if @expense.save
      render :show, status: :created, location: api_v1_occasion_url(@group)
    else
      render_validation_failed @expense, fields: FIELDS
    end
  end

  # Any subset of the fields.
  def update
    if @expense.update(expense_params)
      render :show
    else
      render_validation_failed @expense, fields: FIELDS
    end
  end

  def destroy
    @expense.destroy
    head :no_content
  end

  private
    def set_expense
      @expense = @group.expenses.find(params[:id])
    end

    def expense_params
      params.expect(expense: [ :description, :amount, :payer_id, member_ids: [] ])
    end
end
