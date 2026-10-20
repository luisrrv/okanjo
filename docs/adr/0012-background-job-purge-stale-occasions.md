# 0012. Background job: purge stale occasions

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
The core includes one Solid Queue job, which means it needs real work to do. Occasions are
used once and forgotten, and without cleanup they pile up forever.

## Options considered
1. **A settlement summary sent after an occasion.** Cons: the core has no accounts and no
   email addresses (0016), so the summary has nobody to go to. It would be a job invented
   to prove a job can be written, and that would be obvious.
2. **A recurring purge of stale occasions.** Pros: real work for an app you use and
   forget. It answers where abandoned occasions go, and it exercises
   `config/recurring.yml`, not just `perform_later`.

## Decision
Option 2: a daily recurring Solid Queue task, defined in `config/recurring.yml`, that
deletes occasions nobody has changed within the retention period.

## Consequences
- Retention is 30 days after the last change, and a change is any edit to the occasion's
  members or expenses (0016).
- Deleting a group must also delete its members, expenses and participations. Whether that
  happens through `dependent:` options or foreign-key cascades gets decided in the spec.
- In production the job runs inside Puma (`SOLID_QUEUE_IN_PUMA`, 0017).
