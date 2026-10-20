# 0009. Where the split logic lives

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
Rails teams have strong views on fat models versus service objects. okanjo has logic at
three levels:
- one expense's share;
- a group's balances, which span members, expenses and participations;
- settlement, which turns balances into transfers.

The balance sheet is also where an N+1 query problem naturally appears.

## Options considered
1. **Everything on models** (e.g. `Group#balances`, `Member#balance`). Pros: discoverable.
   Cons: logic spanning several models ends up on whichever model was nearest, and it
   invites the per-member loop that causes the N+1.
2. **Everything in service objects.** Pros: one place for logic. Cons: logic about a single
   record moves away from the record it describes.
3. **Split by what the logic is about.** Logic about one record lives on that model.
   Logic spanning several models lives in a plain Ruby object that takes a group.

## Decision
Option 3.

- `Expense#share_amount`, `#collected` and `#odd_yen` (0008) are about one expense, so
  they live on the model.
- The balance sheet takes a group and returns a balance for each member, computed as
  collected minus owed (0008). It's a plain Ruby object (a query object). It loads the
  group's expenses and participations in two queries and does the arithmetic in Ruby.
- Settlement (0013) is a separate plain Ruby object. It takes the balance sheet's output
  and returns transfers.

## Consequences
- The query count stays the same whatever the group size. At around 30 expenses and 180
  participation rows, the Ruby arithmetic is effectively free.
- On purpose, the naive per-member loop is written first. That's 13 queries if the owed
  side stays flat, or about 193 if it nests through member, participations and expense.
  We find it in `log/development.log`, then fix it. Reading the log is the skill being
  practised.
- This is the answer to "fat model or service object?": the split follows what the logic
  is about, not a blanket rule.
