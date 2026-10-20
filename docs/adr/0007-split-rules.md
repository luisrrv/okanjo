# 0007. Split rules: equal splits, one payer, integer yen

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
Expense-splitting apps support many split modes: unequal amounts, percentages, itemised
bills, several payers per expense. Each mode adds UI, validation and edge cases. The core
is scoped to finish, and a single 飲み会 rarely needs more than an equal split.

## Options considered
1. **Flexible splits** (unequal, percentage, itemised, several payers). Not pursued for
   the core.
2. **Equal splits, one payer per expense, integer yen.**

## Decision
Option 2.

- Each expense is split equally among the members in the split.
- Each expense has exactly one payer.
- All amounts are integer yen in integer columns. Never floats. Yen has no subunit.

## Consequences
- Uneven division is handled by one rule: round each share up, and the payer keeps the
  odd yen (0008).
- A meal where people ordered very different amounts has to be entered as several
  expenses with different members in the split.
- The payer may be left out of the split (0015).
- Another currency or unequal splits would mean revisiting this ADR and 0008.
