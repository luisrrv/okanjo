class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.string :token, null: false
      t.string :name

      t.timestamps
    end
    add_index :groups, :token, unique: true
  end
end
