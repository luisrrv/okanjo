# A printable statement of an occasion; the browser's "Save as PDF" makes the file (ADR 0016).
class ReceiptsController < ApplicationController
  include GroupScoped

  def show
    @expenses = @group.expenses.order(:created_at).includes(:payer, participations: :member)
    @balance_sheet = BalanceSheet.new(@group)
    @settlement = Settlement.new(@balance_sheet.balances)
  end
end
