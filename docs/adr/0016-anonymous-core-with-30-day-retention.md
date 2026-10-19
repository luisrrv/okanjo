# 0016. Anonymous core with 30-day retention and receipts

- Status: Accepted
- Date: 2026-10-19
- Decider: Luis

## Context
Occasions are meant to be used and forgotten. A recurring Solid Queue job deletes the
ones nobody has touched for a while. The original plan also put the Rails 8 auth generator
in the core, so that an account could keep a user's history across occasions. Those two
ideas conflict: deleting untouched occasions also erases account history, and history is
the only reason given for logging in.

A downloadable receipt changes that. Anyone with the occasion link, with or without an
account, can keep their own record of an occasion. That leaves accounts in the core with
one benefit: seeing your occasions on more than one device, since the browser cookie
(0006) only remembers them where you used them.

## Options considered
1. **Two retention periods:** 30 days for anonymous occasions, 1 year for occasions with
   an account member, and a reminder email a month before deletion. Pros: account history
   stays useful and everything is still deleted eventually. Cons: a second rule, a reminder
   email and production email delivery, mostly to protect history the receipt now covers.
2. **Keep login, delete everything after 30 days.** Pros: one rule, and the auth generator
   stays in the core. Cons: login has only a small job (seeing occasions on every device),
   and production email is still needed for password reset.
3. **Anonymous-only core; auth moves to phase 2.** Pros: removes auth and production email
   from the core, and auth arrives when the product needs an identity (LINE in LIFF). Cons:
   Rails 8 auth is only covered if phase 2 ships.

## Decision
Option 3. The core has no login.

- **Retention:** an occasion is deleted 30 days after its last change. A change means
  adding or editing an expense or member, via `belongs_to :group, touch: true`. Viewing
  doesn't count.
- **Deletion notice:** the occasion page shows the date it will be deleted if nothing
  changes. There's no reminder email.
- **Receipt:** a printable page (print stylesheet) with the expenses, who was in each
  split, the shares and the settlement transfers. The browser's "Save as PDF" produces the
  file. It's built in the core and needs no gems.
- **Auth:** the Rails 8 auth generator is the first step of phase 2, before the API and
  LIFF client. It's small and independent, so it lands early even if the rest of phase 2
  takes longer. LINE Login is added on top and reuses the generator's session code.
  Phase 2 will ship.

## Consequences
- The core needs no production email delivery and no user accounts.
- Supersedes the planned backfill ADRs 0010 (auth in the core) and 0011 (the
  `Member.user_id` seam). The nullable `Member.user_id` column is added in phase 2. That's
  purely additive, so it doesn't affect the core's design.
- The purge job is the core's one Solid Queue job: a recurring task in
  `config/recurring.yml` deleting groups whose `updated_at` is older than 30 days.
- The `rails_refresh.md` checklist item "a migration that changes an existing table" was
  going to be adding `display_name` to `users`. The core now needs another example.
- Identity in the core is only the signed cookie (0006). Clearing cookies loses your list
  of occasions, and the receipt is the way to keep a record.
- Phase 2's ADR has to cover the generator first, then LINE Login on the same `User`.
