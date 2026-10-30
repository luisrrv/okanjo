class Group < ApplicationRecord
  has_secure_token

  # Deleted members cascade in the database too (on_delete: :cascade), which is
  # what the purge job relies on when it uses delete_all.
  has_many :members, dependent: :destroy

  normalizes :name, with: ->(name) { name.strip.presence }

  validates :name, length: { maximum: 50 }
end
