class Member < ApplicationRecord
  belongs_to :group, touch: true
  belongs_to :user, optional: true
  has_many :participations, dependent: :restrict_with_error
  has_many :paid_expenses, class_name: "Expense", foreign_key: :payer_id, dependent: :restrict_with_error

  # Members who haven't paid for anything and aren't in any split.
  scope :removable, -> { where.missing(:participations, :paid_expenses) }

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 50 },
                   uniqueness: { scope: :group_id, case_sensitive: false }
  validates :user_id, uniqueness: { scope: :group_id }, allow_nil: true

  # Links this member to an account (ADR 0022). True if it's now (or already) theirs; false,
  # with an error, if another account holds it or the user has another member here.
  # with_lock re-reads the row inside a write transaction, so two accounts claiming at once
  # can't both win.
  def claim_by(user)
    with_lock do
      if user_id.nil?
        update(user: user)
      elsif user_id == user.id
        true
      else
        errors.add(:base, :claimed_by_other)
        false
      end
    end
  rescue ActiveRecord::RecordNotUnique
    errors.add(:user_id, :taken)
    false
  end

  # Only the account holding a member can release it.
  def release_by(user)
    user_id == user.id && update(user: nil)
  end
end
