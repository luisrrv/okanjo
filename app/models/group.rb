class Group < ApplicationRecord
  has_secure_token

  # Children cascade in the database too (on_delete: :cascade), which is what the
  # purge job relies on when it uses delete_all.
  # Order matters: expenses must be destroyed before members, or a member who paid
  # refuses to be destroyed and the whole group destroy fails.
  has_many :expenses, dependent: :destroy
  has_many :members, dependent: :destroy

  normalizes :name, with: ->(name) { name.strip.presence }

  validates :name, length: { maximum: 50 }
end
