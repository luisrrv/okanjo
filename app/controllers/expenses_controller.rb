class ExpensesController < ApplicationController
  allow_unauthenticated_access # occasions never need an account (ADR 0022)
  include GroupScoped
  include CurrentMember

  rate_limit to: 30, within: 1.minute, only: :create
  before_action :set_expense, only: %i[edit update destroy]

  def new
    # Defaults (spec D2, ADR 0015): a numbered label, you as the payer, everyone in the split.
    @expense = Expense.new(
      group: @group,
      description: t("expenses.form.default_description", number: @group.expenses.count + 1),
      payer: current_member,
      members: @group.members
    )
  end

  def create
    @expense = Expense.new(expense_params.merge(group: @group))

    if @expense.save
      redirect_to @group, notice: t(".created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to @group, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @expense.destroy
    redirect_to @group, notice: t(".destroyed")
  end

  private
    def set_expense
      @expense = @group.expenses.find(params[:id])
    end

    def expense_params
      params.expect(expense: [ :description, :amount, :payer_id, member_ids: [] ])
    end
end
