# 0008. Round up each share, compute shares on read

- Status: Accepted
- Date: 2026-10-16
- Decider: Luis

## Context
Splits are equal, with one payer per expense, in integer yen (0007). An amount that doesn't
divide evenly needs a rounding rule, and that rule decides two more things: whether shares
must be stored, and who holds the leftover yen.

The settled rule is that every share rounds up: ¥1000 ÷ 3 → ¥334 each, ¥1002 collected,
¥2 over. Because that is a pure function of (amount, participant count), with no arbitrary
choice of who absorbs the remainder, shares can be computed on read. `Participation` has no
amount column, and editing an expense needs no share rebuild, recompute callback or
denormalised data.

Rounding up has a side effect. If a balance is "paid − owed" and the payer is credited
with the amount paid, the group collects more than was spent and balances no longer sum to
zero. With ¥1000 paid by A and split between A, B and C, the balances are A +666, B −334,
C −334, which sum to −2. Settlement needs a zero-sum input, so the odd yen has to belong to
someone.

## Options considered
1. **Credit the payer with what is collected** (share × participant count). The balances
   above become A +668, B −334, C −334, which sum to 0. The payer keeps the odd yen
   (お釣り). Pros: smallest change to the settled design, keeps round-up, and settlement
   gets a clean zero-sum input. Cons: the payer's effective cost is the lowest in the
   group (¥332 against ¥334), the opposite of the 幹事が多めに出す (organiser pays a bit
   extra) norm.
2. **Credit the amount paid and track the odd yen as a group surplus.** Pros: amounts are
   literal. Cons: settlement has to decide where the surplus goes, which is an arbitrary
   choice at settlement time, the very thing computing shares on read avoids.
3. **Drop round-up: others pay the rounded-down share and the payer absorbs the
   remainder.** Pros: `sum(shares) == amount` exactly, and shares can still be computed on
   read. Cons: reopens a settled rule and drops the お釣り display.

## Decision
Shares round up and are computed on read, never stored. The payer is credited with the
amount collected, not the amount paid. In one sentence: the person who fronted the money
keeps the change.

- `Expense#share_amount`: the amount divided by the participant count, rounded up
- `Expense#collected`: `share_amount * participant count`
- `Expense#odd_yen`: `collected - amount`, shown in the UI as お釣り kept by the payer

## Consequences
- Invariants, which become the model tests:
  - `collected >= amount`
  - `collected - amount < participant count`
  - balances across a group sum to exactly zero
- A `sum(shares) == amount` validation is wrong under this rule. Don't write it.
- The balance sheet credits each payer with `collected`, so settlement always receives
  balances that sum to zero.
- "Balance" no longer means literally what someone paid. The UI and README have to explain
  the お釣り rule.
- If the payer isn't a participant (open decision D), they still collect `collected`,
  e.g. ¥1002 for ¥1000 spent. That stays consistent with this rule.
- Revisit if users expect the payer to absorb the remainder (option 3). That change would
  touch only `share_amount` and the balance sheet, because nothing is stored.
