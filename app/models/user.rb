class User < ApplicationRecord
  # A LINE-only account has no password (ADR 0024), so has_secure_password's own validations,
  # which always require one, are off. The ones an email account needs are written out below,
  # with the same errors.
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  # The database also nullifies (on_delete: :nullify); this keeps it right in Ruby too.
  has_many :members, dependent: :nullify
  has_many :groups, through: :members

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Every user can sign in with LINE, or with an email and a password, or both. The database
  # checks the same rule (users_can_sign_in).
  validates :email_address, presence: true, unless: :line_user_id?
  validates :email_address, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  # line_user_id comes from LINE, never from a form, so only its unique index guards it: a
  # uniqueness validation would turn create_or_find_by!'s race into a RecordInvalid.
  validate :password_with_email
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :password_within_bcrypt_limit
  validates_confirmation_of :password, allow_nil: true

  # Moves a LINE-only account into this one when the person links LINE to their email account
  # (ADR 0024): its claims come here, except where this account already holds a member in that
  # occasion (that claim is released); then it's deleted, and its LINE ID is this account's.
  def merge_line_account!(line_user)
    transaction do
      line_user.members.each do |member|
        member.update!(user: members.exists?(group_id: member.group_id) ? nil : self)
      end
      line_user_id = line_user.line_user_id
      line_user.destroy!
      update!(line_user_id:)
    end
  end

  # Unlinking LINE must leave a way to sign in.
  def can_unlink_line?
    email_address.present? && password_digest.present?
  end

  private
    def password_with_email
      errors.add(:password, :blank) if email_address.present? && password_digest.blank?
    end

    def password_within_bcrypt_limit
      if password.present? && password.bytesize > ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
        errors.add(:password, :password_too_long)
      end
    end
end
