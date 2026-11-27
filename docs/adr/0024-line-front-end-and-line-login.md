# 0024. The LINE front end and LINE Login (slice 2c)

- Status: Accepted
- Date: 2026-11-18
- Decider: Luis

## Context
0021 settled the shape of slice 2c: warikan v1 becomes v2's LINE front end under its existing
LIFF ID, its code moves into this repo as `liff/` with its history (`git subtree`), it's served
at `warikan.lrod.dev/liff`, and it exchanges LINE's ID token for an API token (0023). Its 2026-11-13
update adds two requirements: an email account can link LINE so both sign-ins reach the same
`User`, and the core barely changes.

v1 today is about 780 lines of TypeScript (Vite, pnpm, `@line/liff`): a stateless calculator
that splits a total among N people, rounds each share up to **¥100**, has a JP/EN toggle, and
shares a Flex card through `shareTargetPicker` that links back to
`liff.line.me/<LIFF ID>?total=…&people=…`. It has no LINE Login and no backend.

v2 rounds each share up to the **yen** (0008) and is Japanese only (0018). The users table has
`email_address` and `password_digest` NOT NULL (0022).

## Options considered
**D0. Delivery:** all of 2c at once, or **2c-1** (move v1 in, build and serve it at `/liff`, no
behaviour change) then **2c-2** (LINE Login, linking, screens on the API).

**D1. Rounding:**
1. v2's rule everywhere: up to the yen, computed by the server.
2. A rounding unit per occasion (¥1, ¥10, ¥100): `ceil(amount ÷ (n × unit)) × unit`, still
   zero-sum because the payer is credited with what's collected. A domain change: a migration,
   an amendment to 0008, UI on both front ends.
3. Two rules: the stateless calculator keeps ¥100, occasions use ¥1.

**D2. What the LIFF app does:**
1. An occasion client: LINE sign-in, my occasions, an occasion (members, expenses, settlement),
   add an expense or a member, claim a member, share the occasion to a chat. Editing and
   deleting link to the website.
2. Full parity with the website, including edit and delete.
3. v1's calculator plus a read-only list of my occasions.

**D3. Verifying LINE's ID token:**
1. LINE's verify endpoint (`POST https://api.line.me/oauth2/v2.1/verify`) over `Net::HTTP`: LINE
   checks signature, expiry, audience and nonce and returns the claims. No gem; one call to LINE
   per sign-in, and sign-in fails while LINE is unreachable.
2. Verifying the JWT locally with the `jwt` gem against LINE's published keys (JWKS): no network
   call per sign-in, but a gem, key fetching and caching, and the algorithm checks are ours.

**D4. Storing the LINE identity:**
1. A nullable, unique `users.line_user_id`.
2. An `identities` table (`provider`, `uid`, `user_id`), the multi-provider shape.

**D5. Linking accounts:** create a LINE-only account on first LINE sign-in; link an email account
from inside LIFF by entering its email and password once; merge if the LINE ID already has its
own account; allow unlinking only with another way to sign in. Alternatives: refuse to link when
the LINE ID already has an account (strands its claims), or ask the user which account to keep.

**D6. Building and serving `liff/`:**
1. A Node build stage in the Dockerfile copies the build into `public/liff`; the final image has
   no Node. A `liff` CI job (typecheck and build) is a required check.
2. Commit the built files to `public/liff`, with CI checking they're current. No Node in Docker,
   but build output in git.
3. Keep building and hosting on Netlify, with only the code here. Contradicts 0021.

**D7. Language:** Japanese only (0018), or keep v1's JP/EN toggle while the API's messages stay
Japanese.

## Decision
- **D0: two sub-slices, 2c-1 then 2c-2.** 2c-1 carries the infrastructure risk (a Node build
  stage, CI, the LIFF endpoint change) and ships with no behaviour change. If 2c-2 stalls, there
  is still one warikan in one repo.
- **D1: option 1, v2's rule everywhere.** The calculator switches from ¥100 to ¥1 in 2c-2, and the
  LIFF screens show what the server computes. A per-occasion rounding unit (option 2) is a domain
  feature, not a LINE one; it can be its own small slice after 2c, so 2c stays the evidence that
  LINE was added without touching the core.
- **D2: option 1, the occasion client.** The calculator stays as the signed-out screen, and v1's
  `?total=&people=` links keep opening it. Signing in with LINE is offered from there.
- **D3: option 1, LINE's verify endpoint,** with `Net::HTTP` and no gem. It runs once per sign-in;
  every other request uses our own token (0023). The story stays: LINE issues a JWT, the app
  verifies it, and issues its own server-side token.
- **D4: option 1, `users.line_user_id`.** LINE is the only provider on the roadmap; moving to an
  `identities` table later is one migration. `email_address` and `password_digest` become
  nullable, with `has_secure_password validations: false` and our own rule: a user has a LINE ID,
  or an email and a password, or both.
- **D5: the proposed rules.**
  - A LINE sign-in with an unknown LINE ID creates a LINE-only account. No sign-up form in LINE.
  - Linking an email account happens in LIFF: enter its email and password once, and the server
    attaches the LINE ID to it. No web OAuth flow (callback, `state`, `nonce`) on the website.
  - If the LINE ID already has a LINE-only account, it's merged into the email account in one
    transaction: claims (`members.user_id`) move over; where both hold a member in the same
    occasion, the email account's claim wins and the other is released; the LINE-only account and
    its sessions are deleted. Claims are the only data a user owns.
  - Unlinking LINE is allowed only for an account that can still sign in with email and password.
- **D6: option 1,** a Node build stage and a required `liff` CI job. A broken client build blocks
  a deploy only if it's merged with red CI; that required check is the containment 0021 asked for.
- **D7: Japanese only.** The API's `code` field leaves room for English later.
- **Smaller defaults:**
  - the LIFF app keeps the API token in `localStorage` and reuses it until a `401`, then exchanges
    a fresh ID token, so a launch doesn't create a `Session` row each time;
  - `LINE_CHANNEL_ID` (the LINE Login channel that owns the LIFF app) is plain configuration, not
    a secret;
  - v1's repo is archived with a pointer here once 2c-1 is live.

## Consequences
- **0003 is amended:** the repo builds Node for `liff/` in a Docker build stage and a CI job. The
  Rails app and the final image stay Node-free.
- **0008 holds for both front ends.** v1 users see ¥1 rounding instead of ¥100 after 2c-2, and the
  calculator's numbers change for the same inputs. A rounding unit is a candidate follow-up.
- **0018 holds:** v1's English mode goes away in 2c-2.
- **0022's `NOT NULL`s are relaxed** for LINE-only accounts. Code that assumes a user has an email
  (the password reset, the header) must handle `nil`.
- **Sign-in depends on LINE's availability** for LINE users. Email sign-in and existing tokens are
  unaffected.
- **A merge deletes a user.** It only ever deletes the LINE-only side, and only inside the
  transaction that moves its claims.
- **LINE console tasks are Luis's:** the `openid` scope on the LIFF app, the channel ID, and
  switching the LIFF endpoint URL to `https://warikan.lrod.dev/liff` when 2c-1 ships. Switching it
  back to Netlify is the rollback until the old site is retired.
- **The website's `allow_browser versions: :modern` must not block LINE's in-app browser.** 2c-1
  checks this with LINE's user-agent strings before the endpoint switch.

## Update (2026-11-27): the Netlify site is retired
The old Netlify project (`warikan-jp.netlify.app`) is disabled, after 2c-2 was verified in
production and the LIFF endpoint was confirmed at `https://warikan.lrod.dev/liff`. Switching the
endpoint back to Netlify is no longer a rollback. The project is disabled rather than deleted so
the `warikan-jp.netlify.app` name stays reserved and can't be claimed by someone else.
