class Member < ApplicationRecord
  belongs_to :group, touch: true
  has_many :participations, dependent: :restrict_with_error
  has_many :paid_expenses, class_name: "Expense", foreign_key: :payer_id, dependent: :restrict_with_error

  # Members who haven't paid for anything and aren't in any split.
  scope :removable, -> { where.missing(:participations, :paid_expenses) }

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 50 },
                   uniqueness: { scope: :group_id, case_sensitive: false }
end
