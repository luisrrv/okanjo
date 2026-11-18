# LINE as a second sign-in on the same User (ADR 0024). A LINE-only account has no email or
# password, so those become nullable, and a check keeps every user able to sign in somehow.
class AddLineUserIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :line_user_id, :string
    add_index :users, :line_user_id, unique: true

    change_column_null :users, :email_address, true
    change_column_null :users, :password_digest, true

    add_check_constraint :users,
      "line_user_id IS NOT NULL OR (email_address IS NOT NULL AND password_digest IS NOT NULL)",
      name: "users_can_sign_in"
  end
end
