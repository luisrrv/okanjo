class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  # The database also nullifies (on_delete: :nullify); this keeps it right in Ruby too.
  has_many :members, dependent: :nullify
  has_many :groups, through: :members

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # has_secure_password already requires a password on create and caps it at 72 bytes.
  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
