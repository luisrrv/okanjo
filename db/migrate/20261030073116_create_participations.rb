class CreateParticipations < ActiveRecord::Migration[8.1]
  def change
    create_table :participations do |t|
      # No separate expense_id index: the unique [expense_id, member_id] index below covers it.
      t.references :expense, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :member, null: false, foreign_key: true

      t.timestamps
    end
    add_index :participations, [ :expense_id, :member_id ], unique: true
  end
end
