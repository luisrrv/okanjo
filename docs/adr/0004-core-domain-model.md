# 0004. Core domain model

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
The original warikan is a stateless calculator. The rebuild keeps its spirit (no signup,
usable in 30 seconds) but adds real persistence. The model should be the smallest one that
covers an occasion's expenses and its settlement.

## Options considered
The design started with more models, and each was removed for a reason:
- **`Invitation`:** the invite link is the group URL with its token (0005).
- **`Calculation`:** it was `Expense` all along.
- **`Payment`:** an occasion settles once, and everyone pays outside the app. Settlement is
  computed on read (0013).
- **`occurred_on` on `Expense`:** `created_at` is enough for a bill settled in one
  sitting.

## Decision
Four models:

```
Group          token (has_secure_token)
Member         belongs_to :group; name only
Expense        belongs_to :group
               belongs_to :payer, class_name: "Member"
               amount (integer yen)
Participation  belongs_to :expense
               belongs_to :member; join model, no amount column
```

`Expense has_many :participations` and `has_many :members, through: :participations`.

## Consequences
- Shares aren't stored, because they're computed from amount and participant count (0008).
  That's why `Participation` has no amount column.
- No identity spans groups (0006). `Member.user_id` arrives in phase 2 (0016).
- `participations [expense_id, member_id]` is unique, and payers and participants must
  belong to the expense's group (0015).
- Adding or changing a member or expense touches the group (`touch: true`), which drives
  retention (0016).
