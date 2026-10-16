# 0013. Settle through a single collector

- Status: Accepted
- Date: 2026-10-16
- Decider: Luis

## Context
An occasion has several expenses, often with different payers. Netting each member's
balance (paid − owed, see 0008) already removes most transfers. In a five-person night out
(1次会 paid by Aki, 2次会 by Ben, taxi by Dai) it cuts seven per-expense transfers to four.
Netting doesn't say who pays whom, though, and many sets of transfers clear the same
balances.

The usual framing is "minimise transfers". In practice the cost is how people react to the
transfers. Greedy matching cleared the night out in four transfers, but one of them had Emi
pay Ben, although Emi went home before the bar Ben paid for. The amount is right, and it
still reads as a bug to the person paying. Splitwise has the same tradeoff and leaves it
to the user with its per-group "Simplify debts" setting.

okanjo groups are single occasions, usually with one person who covered most of it. Cash
splits at hangouts already work through that person: everyone settles with the 幹事.

## Options considered
1. **Pairwise netting** (Splitwise's default). Each payment goes to someone who paid for
   you. Cons: barely reduces transfers (seven in the example).
2. **Greedy: largest debtor pays largest creditor.** At most n−1 transfers. Cons: pairs
   people arbitrarily (Emi → Ben).
3. **Exact minimum.** Finding the zero-sum subsets is NP-hard, but cheap at dinner-party
   sizes. Cons: rarely beats greedy with real yen amounts, harder to read, and has the
   same arbitrary pairings.
4. **Only between people who shared an expense.** Cons: can need more transfers, and
   needs the expenses as input, not just the balances.
5. **A single collector.** One member settles with everyone else. Pros: matches how cash
   is split at hangouts, explains itself in the UI ("pay Aki"), and is the simplest code.
   Cons: always n−1 transfers when everyone has a non-zero balance, and one person
   handles all the money.
6. **A toggle between two of these.** Cons: both algorithms plus a setting and UI, for an
   app meant to be usable in 30 seconds.

For who the collector is:
- **a. Automatic: the member with the largest positive balance.** No UI and no schema
  change.
- **b. Chosen by the user:** a nullable `groups.collector_member_id`. Cons: a data model
  change, a form and a fallback, and a collector who owes money must gather the debtors'
  payments before paying out.

## Decision
Settle through a single collector (option 5). The collector is chosen automatically as the
member with the largest positive balance, with ties going to whoever joined the group
first (option a).

Every other member with a non-zero balance makes one transfer: debtors pay the collector
what they owe, and the collector pays other creditors what they are owed. If every balance
is zero, there are no transfers.

The reason is trust, not the number of transfers. Paying the 幹事 is the arrangement
people already use and don't question. We accept that it isn't the fewest possible
transfers and that a debtor's payment can cover expenses the collector didn't pay for.

## Consequences
- Settlement is a pure function of the balance sheet, computed on read and never stored,
  consistent with having no `Payment` model.
- At most n−1 transfers, never fewer than greedy's worst case, and sometimes more than
  greedy or the exact minimum. The README should say so and why.
- The tie-break makes the result stable across page loads.
- The collector can change when expenses are added. A large new expense can move the role
  to someone else after people have started paying. If that turns out to be a real
  problem, add a chosen collector (option b). The column is purely additive.
- Phase 2: a LINE group usually has an obvious 幹事, which may be the point at which a
  chosen collector becomes worth adding.
