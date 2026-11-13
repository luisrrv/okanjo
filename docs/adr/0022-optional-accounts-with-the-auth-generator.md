# 0022. Optional accounts with the Rails 8 auth generator (slice 2a)

- Status: Accepted
- Date: 2026-11-13
- Decider: Luis

## Context
Slice 2a (0021) adds accounts so a user can see their occasions on any device; today only the
browser cookie remembers them (0006). Accounts stay optional: an anonymous occasion must keep
working end to end (0016).

The installed generator (Rails 8.1.4.1) doesn't fit as it ships:
- it adds `before_action :require_authentication` to every controller;
- its `ApplicationCable::Connection` rejects connections without a signed-in user, which would
  break live refresh (0019) for anonymous visitors;
- it has no sign-up, only sign-in, sign-out and password reset;
- it needs the `bcrypt` gem;
- password reset sends email, and production can't send any yet.

Three decisions follow: how production sends email, whether accounts change the 30-day
deletion, and how an account is linked to a member.

## Options considered
**Sending email** (only password resets, so tens a month at most):
1. **Oracle Email Delivery over SMTP.** 3,000 emails a month in Always Free, then $0.085 per
   1,000. Pros: the same account and budget alert as the server and backups; no new provider.
   Cons: Oracle's console has been slow to set up before (capacity, key activation).
2. **Resend over SMTP.** 3,000 a month free, at most 100 a day. Pros: the easiest setup, good
   logs. Cons: another provider and account.
3. **Postmark** (100 a month free) or **Amazon SES** (credits for 6 months only). Cons: a
   tight cap, or a new AWS account with sandbox approval.
4. **No email; hide password reset.** Cons: a forgotten password locks the user out for good.

**Accounts and the 30-day deletion:**
1. **No change.** "My occasions" lists the user's occasions that still exist. One rule.
2. **Keep occasions with an account member for longer.** This is 0016's rejected option 1,
   with reminder emails and two rules.

**Linking an account to a member** (the nullable `members.user_id` from 0016):
1. **Choosing "I'm this member" while signed in claims it.** Creating an occasion while
   signed in claims its first member, and signing in claims the members this browser's
   cookie remembers. Pros: reuses the existing flow; no new screen. Cons: someone with the
   link can claim a member before the real person does.
2. **A separate "add to my occasions" button.** Cons: two similar actions side by side.
3. **Claim only on sign-in, from the cookie.** Cons: occasions joined after signing in are
   never claimed.

## Decision
- **Email: Oracle Email Delivery over SMTP** (option 1), through Action Mailer, with no gem.
  It sends from `warikan.lrod.dev`, with SPF, DKIM and DMARC records at Gandi. If Oracle's
  setup fails twice, switch to Resend; the Rails code doesn't change.
- **The 30-day deletion doesn't change** (option 1). An account gives you your occasions on
  every device, not permanent history; the receipt is the permanent record (0016).
- **Claiming: option 1**, with these rules:
  - at most one member per user in each occasion (a unique index on `[group_id, user_id]`;
    SQLite allows many NULLs in it);
  - a member claimed by another account can't be claimed, and shows a 連携済み badge;
  - only the account that claimed a member can release it;
  - deleting a user sets `user_id` to NULL on their members.
- **A claim is about listing, not access.** Anyone with the link can still view the occasion
  and act as any member, claimed or not (0006). Locking claimed members is out of scope.
- **The generator runs as it ships, with four changes:**
  - `allow_unauthenticated_access` on every existing controller, so login is never required
    for occasions;
  - the Action Cable connection accepts everyone and identifies the user only when signed in;
  - a hand-written sign-up (`resource :registration`);
  - `bcrypt`, uncommented in the Gemfile. This ADR is its gem ADR.

## Consequences
- **Rails 8 auth is covered,** the gap 0016 accepted, even if phase 2 stops here.
- **Production depends on email for the first time:** a sending domain, DNS records, SMTP
  credentials in the keychain and `.kamal/secrets`. 2a doesn't deploy until a real reset email
  arrives.
- **0006 is amended:** a signed-in user's member in an occasion comes from `members.user_id`
  first, then the cookie.
- **Email addresses aren't confirmed.** Someone could sign up with another person's address;
  the owner of the address can take the account back with a password reset. Confirmation can
  come later if needed.
- **The claim race is accepted:** someone with the link can claim your name first. The badge
  makes it visible, and occasions are among people who know each other.
- **LINE accounts (2c) aren't designed here.** 2a assumes nothing that 2c will have to undo
  beyond the generator's `email_address NOT NULL`, which 2c's migration can relax.
- **Users and sessions aren't purged.** An account outlives its occasions; account deletion is
  a follow-up.
