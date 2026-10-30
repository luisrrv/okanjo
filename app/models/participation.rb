class Participation < ApplicationRecord
  belongs_to :expense, touch: true
  belongs_to :member

  validates :member_id, uniqueness: { scope: :expense_id }
end
