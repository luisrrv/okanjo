class Expense < ApplicationRecord
  # SQLite integers are 8 bytes, and Rails raises ActiveModel::RangeError on save above
  # 9,223,372,036,854,775,807. This ceiling turns huge amounts into a validation error
  # and keeps them within a 4-byte integer (spec D5).
  MAX_AMOUNT = 2_000_000_000

  belongs_to :group, touch: true
  belongs_to :payer, class_name: "Member"
  has_many :participations, dependent: :destroy
  # dependent: :destroy here makes member_ids= destroy removed join rows instead of
  # deleting them, so Participation's touch runs and the group's last change moves.
  has_many :members, through: :participations, dependent: :destroy

  normalizes :description, with: ->(description) { description.strip }

  validates :description, presence: true, length: { maximum: 100 }
  validates :amount, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_AMOUNT }
  validates :members, presence: true
  validate :payer_belongs_to_group, :members_belong_to_group

  # Each share rounds up; the payer is credited with what's collected and keeps the odd yen (ADR 0008).
  def share_amount
    amount.ceildiv(participations.size)
  end

  def collected
    share_amount * participations.size
  end

  def odd_yen
    collected - amount
  end

  private
    def payer_belongs_to_group
      errors.add(:payer, "must belong to this group") if payer && payer.group_id != group_id
    end

    def members_belong_to_group
      errors.add(:members, "must all belong to this group") if members.any? { |member| member.group_id != group_id }
    end
end
