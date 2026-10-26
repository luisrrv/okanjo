# Spec: domain model

- Status: Accepted
- ADRs: 0004, 0005, 0007, 0008, 0009, 0012, 0015, 0016

## Goal
The four core models (Group, Member, Expense, Participation), with their tables,
associations, validations and the per-expense share methods. Everything is correct in
`rails console` and covered by model specs before any UI exists.

## Out of scope
- Routes, controllers, views and forms (session 2).
- The balance sheet and settlement objects (0009, 0013). The invariant "balances sum to
  zero" is tested with them, not here.
- The signed-cookie identity (0006), the purge job (0012) and the receipt (0016).
- `Member.user_id` (phase 2, 0016).

## Data model

Every table also has `created_at` and `updated_at`. SQLite enforces foreign keys in
Rails 8, so the constraints below are real.

### groups
| Column | Type | Constraints |
|---|---|---|
| `token` | string | not null, unique index; `has_secure_token` |
| `name` | string | optional, at most 50 characters (D1) |

### members
| Column | Type | Constraints |
|---|---|---|
| `group_id` | references | not null, foreign key `on_delete: :cascade` (D3) |
| `name` | string | not null; `collation: "NOCASE"`; unique index on `[group_id, name]` (D4) |

### expenses
| Column | Type | Constraints |
|---|---|---|
| `group_id` | references | not null, foreign key `on_delete: :cascade` (D3) |
| `payer_id` | references → `members` | not null, foreign key (default, no `on_delete`) |
| `description` | string | not null; the form pre-fills お会計 N (D2) |
| `amount` | integer | not null; whole yen, `> 0`, `<= 2_000_000_000` (D5) |

### participations
| Column | Type | Constraints |
|---|---|---|
| `expense_id` | references | not null, foreign key `on_delete: :cascade` (D3) |
| `member_id` | references | not null, foreign key (default, no `on_delete`) |
| | | unique index on `[expense_id, member_id]` (0015) |

## Associations

```ruby
class Group < ApplicationRecord
  has_secure_token
  # Order matters: expenses must go before members, or a member who paid
  # refuses to be destroyed and the whole group destroy fails.
  has_many :expenses, dependent: :destroy
  has_many :members, dependent: :destroy
end

class Member < ApplicationRecord
  belongs_to :group, touch: true
  has_many :participations, dependent: :restrict_with_error
  has_many :paid_expenses, class_name: "Expense", foreign_key: :payer_id,
                           dependent: :restrict_with_error
end

class Expense < ApplicationRecord
  belongs_to :group, touch: true
  belongs_to :payer, class_name: "Member"
  has_many :participations, dependent: :destroy
  has_many :members, through: :participations
end

class Participation < ApplicationRecord
  belongs_to :expense, touch: true
  belongs_to :member
end
```

- `touch: true` updates the parent's `updated_at` whenever a record is created, changed or
  deleted. A change to a participation touches its expense, which touches the group. The
  group's `updated_at` is therefore "last change", which drives retention (0016).
- **Gap to check:** when `member_ids=` removes someone from the split, Rails *deletes* the
  join row without running callbacks (that's how `has_many :through` works), so `touch`
  doesn't fire. If the spec below confirms this, touch the expense explicitly when its split
  changes.

## Validations
| Model | Rule | Source |
|---|---|---|
| Member | `name` present, at most 50 characters | |
| Member | `name` unique within the group, ignoring case; error, no auto-rename | D4 |
| Expense | `description` present, at most 100 characters | D2 |
| Expense | `amount` is an integer, `> 0` and `<= 2_000_000_000` | 0007, D5 |
| Expense | at least one member in the split | 0015 |
| Expense | payer belongs to the expense's group | 0015 |
| Expense | every member in the split belongs to the expense's group | 0015 |
| Participation | `member_id` unique per expense, backed by the unique index | 0015 |

There's deliberately **no** validation that the payer is in the split (0015), and **no**
validation that the shares add up to the amount (0008).

## Interface: per-expense methods (0008, 0009)

```ruby
expense.share_amount  # amount.ceildiv(participant count): each share, rounded up
expense.collected     # share_amount * participant count
expense.odd_yen       # collected - amount; the お釣り the payer keeps
```

- `Integer#ceildiv` (Ruby 3.2+) rounds up integer division without floats:
  `1000.ceildiv(3) == 334`.
- The participant count uses `participations.size`. It reads the already-loaded records
  when they're preloaded and runs a `COUNT` query otherwise. The balance sheet relies on
  this to avoid an N+1.
- Members in the split are assigned through the `has_many :through` writer:
  `expense.member_ids = [aki.id, ben.id]`.

## Decisions

- **D1:** groups get an optional `name` (e.g. 忘年会), at most 50 characters. When it's
  blank, the creation date is shown instead.
- **D2:** `description` is required. The new-expense form pre-fills お会計 N, where N is the
  group's expense count + 1, and the user can overwrite it. Labels are plain text once
  saved, so after a deletion a number can repeat. That's accepted because the user sees and
  can edit them. The model has no defaulting logic.
- **D4:** member names are unique within a group, ignoring case (Yuki = yuki). A duplicate
  is a validation error, and the user picks a distinct name. There's no auto-numbering,
  because the person adding knows who's who and a suffix like "Yuki 2" carries no meaning.
  A `NOCASE` column collation backs this with a case-insensitive unique index. `NOCASE`
  only folds ASCII, which is enough because kana have no case.
- **D5:** `amount <= 2_000_000_000` as a technical ceiling. Rails treats integer columns as
  4 bytes by default (max 2,147,483,647), so a larger value would raise on save and show a
  500 page. The ceiling turns that into a validation error. It isn't meant to catch typos;
  showing the amount back formatted (¥200,000) does that.

- **D3:** both mechanisms, the usual Rails combination.
  - **In the models:** `dependent: :destroy` (see Associations). This is the conventional,
    visible declaration, used for deletes a user triggers one at a time. Callbacks and
    `touch` run normally.
  - **In the database:** `on_delete: :cascade` on `groups → members`, `groups → expenses`
    and `expenses → participations`. This guarantees integrity however a row is deleted,
    and lets the purge job (0012) delete stale groups in one statement with
    `Group.where(...).delete_all`. The job has a comment saying it deliberately skips
    callbacks.
  - `expenses.payer_id` and `participations.member_id` keep the default foreign key, with
    no `on_delete`. SQLite checks those at the end of the statement, so a group cascade
    still succeeds.
  - **Removing members:** a member who paid for something or is in a split can't be
    deleted (`restrict_with_error`), and the UI says why. Members with no expenses can be
    deleted freely.
  - *Accepted cost:* two mechanisms for one rule, and a reader has to know the purge job
    takes the database route. A spec for each route keeps both honest.

## Edge cases
| Case | Expected |
|---|---|
| ¥1000 split 3 ways | `share_amount` 334, `collected` 1002, `odd_yen` 2 |
| ¥1000 split 4 ways | 250 / 1000 / 0 |
| Only one member in the split | `share_amount == amount`, `odd_yen` 0 |
| ¥1 split 3 ways | 1 / 3 / 2. The bound `odd_yen < count` holds |
| Payer not in the split (Dai's ¥8,000 for 3) | valid; 2667 / 8001 / 1 |
| Nobody in the split | invalid |
| Payer or a split member from another group | invalid (crafted request) |
| Same member added to the split twice | invalid; the index also blocks it |
| `amount` 0, negative or decimal (`1000.5`) | invalid |
| `amount` 2,000,000,001 | a validation error, not a 500 from Rails' 4-byte integer limit |
| Member "yuki" when "Yuki" exists in the group | invalid: name already taken |
| Changing the members in the split | shares change on the next read; nothing stored to rebuild |
| Adding or editing an expense | group `updated_at` moves forward |
| `group.destroy` on a group whose members paid for expenses | succeeds; members, expenses and participations are all gone |
| `Group.where(id: group.id).delete_all` (the purge route) | the same, through the database cascade |
| Removing someone from the split only (`member_ids=`) | group `updated_at` still moves forward (see Gap to check) |
| Deleting a member who paid for an expense | rejected, with an error on the member |

## Verification
1. **Model specs** (`spec/models/`), following ADR 0014's readable-RSpec rule:
   - `expense_spec.rb`:
     - the share methods for each edge case above;
     - the 0008 invariants: `collected >= amount` and `collected - amount < count`,
       checked across amounts 1–1000 and member counts 1–10;
     - every validation in the table.
   - `member_spec.rb`: name validations, and deletion rejected while referenced.
   - `group_spec.rb`: a token is generated; deletion cascades through both routes
     (`destroy` and `delete_all`); `touch` moves `updated_at`, including when only the
     split changes.
   - `participation_spec.rb`: uniqueness.
2. **Factories** (`spec/factories/`): `group`, `member` and `expense`. By default an
   expense's payer and members are built in the same group, so a factory can't create a
   cross-group record by accident.
3. **Seeds** (`db/seeds.rb`): the five-person night out from ADR 0013's discussion
   (1次会, 2次会, taxi). Check in `rails console`:
   `Expense.find_by(description: "1次会").share_amount # => 4000`.
4. `bundle exec rspec`, `bin/rubocop` and `bin/brakeman` all pass. The first migration
   also creates `db/schema.rb`, which fixes the CI test jobs.

## Rails-refresh checklist coverage
- Migrations, associations including `has_many :through`, validations, generators (read
  what they write before editing).
- "A migration that changes an existing table": D1's `name` could be added
  in its own migration after `groups` exists. That's staged, since we already know we want
  the column. A more realistic example will likely come up in session 2 or 3. Decide then.
