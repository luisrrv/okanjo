# Links a member to an account (ADR 0022). Nullable: most members have no account.
class AddUserToMembers < ActiveRecord::Migration[8.1]
  def change
    # Deleting a user unlinks their members; the occasions keep them.
    add_reference :members, :user, foreign_key: { on_delete: :nullify }, index: false

    # One member per user in each occasion. user_id first, so the same index serves
    # "this user's occasions". SQLite allows any number of NULLs in a unique index.
    add_index :members, %i[user_id group_id], unique: true
  end
end
