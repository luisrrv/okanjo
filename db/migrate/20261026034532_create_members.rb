class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      # No separate group_id index: the unique [group_id, name] index below covers it.
      t.references :group, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, collation: "NOCASE"

      t.timestamps
    end
    add_index :members, [ :group_id, :name ], unique: true
  end
end
