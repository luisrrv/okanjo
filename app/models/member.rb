class Member < ApplicationRecord
  belongs_to :group, touch: true

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 50 },
                   uniqueness: { scope: :group_id, case_sensitive: false }
end
