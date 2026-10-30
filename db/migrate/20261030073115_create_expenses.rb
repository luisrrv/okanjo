class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :group, null: false, foreign_key: { on_delete: :cascade }
      # No on_delete: a member who paid for something can't be deleted on their own.
      t.references :payer, null: false, foreign_key: { to_table: :members }
      t.string :description, null: false
      t.integer :amount, null: false

      t.timestamps
    end
  end
end
