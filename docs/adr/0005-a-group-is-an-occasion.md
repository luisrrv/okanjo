# 0005. A group is an occasion

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
In the original LIFF app, the LINE chat was the group: membership came for free. On the
web there is no chat, so a group has to be created and shared by hand. The question is
whether a group is a lasting circle of friends or a single occasion.

## Options considered
1. **A persistent circle** that is reused across occasions. Cons: every new calculation
   has to find the right existing group, a branch that can silently attach expenses to
   the wrong group. It also needs an identity to own the circle.
2. **An occasion.** Every new calculation creates a new group, unconditionally. Pros: no
   lookup and no "does this user already have a group" branch, so that whole class of bug
   disappears.

## Decision
Option 2. A group is one occasion (tonight's dinner, one trip). It has no owner. Its
`has_secure_token` token is in its URL, and that URL is the invite link: there's no
`Invitation` model.

## Consequences
- The token is the only access control: anyone with the link can view and edit the
  occasion. Abuse is limited by `rate_limit` (0017).
- Old occasions are deleted 30 days after the last change (0016).
- Members don't carry over between occasions (0006).
