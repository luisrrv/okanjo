class Group < ApplicationRecord
  has_secure_token

  normalizes :name, with: ->(name) { name.strip.presence }

  validates :name, length: { maximum: 50 }
end
