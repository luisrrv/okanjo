class Group < ApplicationRecord
  RETENTION = 30.days

  has_secure_token

  # Children cascade in the database too (on_delete: :cascade), which is what the
  # purge job relies on when it uses delete_all.
  # Order matters: expenses must be destroyed before members, or a member who paid
  # refuses to be destroyed and the whole group destroy fails.
  has_many :expenses, dependent: :destroy
  has_many :members, dependent: :destroy

  # Creating an occasion also creates its first member: whoever is creating it.
  accepts_nested_attributes_for :members

  normalizes :name, with: ->(name) { name.strip.presence }

  validates :name, length: { maximum: 50 }

  # URLs use the token, never the guessable id.
  def to_param
    token
  end

  # Deleted this many days after the last change if nothing else changes (ADR 0016).
  def deletion_date
    (updated_at + RETENTION).to_date
  end
end
