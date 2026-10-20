# 0006. Members belong to one occasion; anonymous identity via a signed cookie

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
LIFF provided a stable identity (`liff.getProfile()`). The web doesn't, and the core has
no login (0016). The app still needs to know which member this browser is, so it can
default the payer (0015), and which occasions this browser has used.

## Options considered
1. **Accounts with a user identity across occasions.** Deferred to phase 2 (0016).
2. **Members that belong to one occasion, plus a signed cookie.** Yuki at tonight's dinner
   and Yuki last month are unrelated rows. A signed cookie maps this browser to its member
   in each occasion, and its list of occasion tokens is this browser's history.

## Decision
Option 2. A member is a name inside one occasion. The browser's identity is a signed
cookie recording, for each occasion token, which member this browser is.

## Consequences
- No sign-up. An occasion works end to end in a single browser session.
- Clearing cookies or switching devices loses the history and the member mapping. The
  printable receipt is how a record is kept (0016). This is also the honest reason for
  accounts in phase 2.
- A signed cookie can't be tampered with but isn't encrypted. It holds occasion tokens,
  which the browser already has from the URL.
- How a browser picks or claims its member is a UI decision for the spec.
