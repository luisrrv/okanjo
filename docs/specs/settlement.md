# Spec: balances, settlement and live refresh (session 3)

- Status: Implemented (2026-11-02)
- ADRs: 0008, 0009, 0013, 0019
- Depends on: [domain model](domain-model.md), [core flow](core-flow.md)

## Goal
The occasion page shows, for each member, what they're credited with, what they owe and
their balance, then who pays whom through the collector (幹事). The page updates live for
everyone viewing it. Along the way, the N+1 in the naive balance sheet is written, found in
the log, and fixed, in two commits.

## Out of scope
- Marking transfers as paid (no `Payment` model, 0004).
- The printable receipt and the purge job (session 4).
- The exact minimum or graph-constrained settlement (0013).

## Where the code lives (D1)
`BalanceSheet` and `Settlement` are plain Ruby classes in `app/models/`, next to the Active
Record models.

**Why `app/models/`:** in Rails, "model" means a domain object, with or without a database
table. Rails autoloads the folder with no configuration, and Rails core and 37signals keep
plain Ruby domain objects there. A separate `app/services/` or `app/queries/` folder would
add a convention the project doesn't otherwise need. Each class starts with a one-line
comment saying it has no table, for readers who expect only Active Record there.

## BalanceSheet (0009)

```ruby
sheet = BalanceSheet.new(group)
sheet.rows      # one Row per member, in join order (member id)
sheet.balances  # { member => balance }, the input for Settlement

Row = Data.define(:member, :credited, :owed) do
  def balance = credited - owed
end
```

- **credited:** the sum of `expense.collected` over the expenses this member paid (0008:
  the payer is credited with what's collected, so they keep the odd yen).
- **owed:** the sum of `expense.share_amount` over the expenses whose split includes this
  member.
- **balance = credited − owed.** Positive means they receive money, negative means they
  pay.
- **Invariant:** balances across the group sum to exactly zero (0008).

### The N+1 exercise (D2)
1. **Commit 1, the naive version:** for each member, loop over `member.paid_expenses` and
   `member.participations`, then each participation's expense and its participation count.
   That's queries inside a loop inside a loop. Check `log/development.log` for the seeded
   night out, and record the measured query count in the commit message.
2. **Commit 2, the fix:** load the group's members, expenses and participations once
   (`group.expenses.includes(:participations)`, plus the members), and do the arithmetic in
   Ruby. The query count stays the same whatever the group size.
3. **A query-count spec** subscribes to `sql.active_record` notifications and asserts the
   same number of queries for a group with 2 members as for one with 10. It's written in
   commit 2 and would fail against commit 1.

## Settlement (0013)

```ruby
settlement = Settlement.new(sheet.balances)
settlement.collector  # the member with the largest positive balance, or nil when everyone is at zero
settlement.transfers  # [Transfer(from:, to:, amount:)]

Transfer = Data.define(:from, :to, :amount)
```

- **Collector:** the largest positive balance. Ties go to whoever joined first (lowest
  member id).
- **Transfers:** each other member with a non-zero balance makes one transfer. A negative
  balance pays the collector; a positive balance is paid by the collector. Members at zero
  don't appear.
- **Ordering:** payments to the collector first, then payments from the collector, each in
  join order.
- **Invariants (specs):**
  - after applying the transfers, every balance is zero;
  - the number of transfers is at most n−1;
  - the collector never transfers to themselves;
  - every amount is positive.

## Page: the 精算 (settle up) section
At the top of the occasion page, above 支払い (payments) and メンバー (members).

- **Balances:** a row per member: name, "立て替え {credited} · 負担 {owed}" ("fronted · owes"),
  and the balance with a sign and colour (green for receives, red for pays).
- **Transfers:** "{collector}さんがまとめて精算します" ("{collector} collects and settles
  up"), then one line per transfer, "{from}さん → {to}さん {amount}".
- **Nothing to settle:** "精算はありません" ("nothing to settle"), when there are no
  expenses or every balance is zero.

### Copy

Revised after the native-speaker review (2026-11-11). `config/locales/ja.yml` is the source of
truth; this table is the original draft.

Glosses are in English. A native speaker should review it before launch.

| Key | Japanese | English gloss |
|---|---|---|
| `settlements.settlement.heading` | 精算 | Settle up |
| `settlements.settlement.row` | 立て替え %{credited} · 負担 %{owed} | Fronted %{credited} · owes %{owed} |
| `settlements.settlement.receives` | +%{amount} | +%{amount} (receives) |
| `settlements.settlement.pays` | −%{amount} | −%{amount} (pays) |
| `settlements.settlement.collector` | %{name}さんがまとめて精算します | %{name} collects and settles up |
| `settlements.settlement.transfer` | %{from}さん → %{to}さん %{amount} | %{from} → %{to} %{amount} |
| `settlements.settlement.nothing` | 精算はありません | Nothing to settle |

## Live refresh (0019)
- `Group`: `broadcasts_refreshes`.
- `groups/show`: `turbo_stream_from @group`.
- Layout head: `turbo_refreshes_with method: :morph, scroll: :preserve`.
- Because members, expenses and participations `touch` the group, every change broadcasts
  one refresh. That depends on `touch` running the group's commit callbacks, which a spec
  confirms.

## Edge cases
| Case | Expected |
|---|---|
| No expenses | every row 0円; "精算はありません" |
| ¥1,000 split 3 ways, paid by Aki | Aki +668 (credited 1,002, owes 334), the other two −334 each; sums to 0 |
| Payer left out of the split (Dai, ¥8,000 for 3) | Dai +8,001; the three −2,667 each; sums to 0 |
| Two members tie for the largest balance | the one who joined first collects |
| Everyone already at zero (e.g. two expenses cancel out) | no collector, no transfers |
| The seeded night out | Aki +16,000, Ben +2,000, Chie −8,500, Dai −5,500, Emi −4,000. Aki collects: Chie → Aki 8,500, Dai → Aki 5,500, Emi → Aki 4,000, Aki → Ben 2,000 |

## Verification
1. **Model specs:**
   - `balance_sheet_spec.rb`: the edge cases above; balances sum to zero across random
     groups (1–8 members, 1–10 expenses, random amounts and splits); the query-count spec.
   - `settlement_spec.rb`: collector choice and ties; transfer direction and ordering; the
     four invariants on the same random groups.
2. **Live refresh:**
   - a model spec that adding an expense broadcasts a refresh on the group's stream, using
     turbo-rails' test helpers;
   - a manual check in two browser tabs that one tab updates when the other adds an
     expense, including whether typing in the add-member field survives a refresh.
3. **Request spec:** the occasion page shows the seeded night out's balances and transfers.
4. `bundle exec rspec`, `bin/rubocop`, `bin/brakeman`, and a phone-width look in the browser
   pane.

## Implementation steps
1. `BalanceSheet`, the naive version, plus its value specs. **Commit 1**, with the log's
   query count in the message.
2. Fix the N+1, plus the query-count spec. **Commit 2.**
3. `Settlement`, with its specs.
4. The 精算 section on the occasion page, its copy, and the request spec.
5. Live refresh, its spec and the two-tab check. Update `ARCHITECTURE.md`.
