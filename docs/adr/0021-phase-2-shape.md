# 0021. Phase 2: accounts, an external-grade API, and v1 as the LINE front end

- Status: Accepted
- Date: 2026-11-13
- Decider: Luis

## Context
The core is live (0017). Phase 2 was set out in 0016 and `CLAUDE.md`:
1. the Rails 8 auth generator (email and password), going first;
2. a nullable `Member.user_id`, linking members to accounts;
3. a JSON API;
4. a LIFF front end inside LINE;
5. LINE Login as a second sign-in strategy on the same `User`.

That's five features. Finishing matters more than scope, so phase 2 needs to stay useful even
if it stops partway. Separately, warikan v1 (a LIFF calculator with share-to-chat, in its own
repo on Netlify) still shares the product name with this app (0017 update).

The project is a showcase. Phase 2 should show Rails as both a full-stack Hotwire app and an
API backend for a separate client, and general API skills, not only Rails ones.

## Options considered
**Delivery:** all five features at once, or **three slices that each ship on their own:**
- 2a: features 1 and 2;
- 2b: feature 3;
- 2c: features 4 and 5.

**The LIFF front end:**
1. **Evolve warikan v1 into v2's LINE front end,** under the same LIFF ID. Pros: one product
   with two front ends; reuses working LIFF code; old LINE share links keep working; resolves
   the naming. Cons: TypeScript work, the half already mastered.
2. **A new LIFF client.** Pros: a clean slate. Cons: rebuilds what v1 does, and leaves two
   apps with one name.
3. **The Hotwire app inside LIFF, no API.** Pros: least work, all Rails. Cons: drops the JSON
   API, the showcase the roadmap chose.

**Where the client lives:**
1. **Separate repos and addresses.** Pros: forces real API discipline (token auth, CORS,
   independent deploys). Cons: two repos for a reviewer; cross-origin setup.
2. **In this repo, served from `warikan.lrod.dev/liff`.** Pros: one project, one deploy, one
   CI; same address. Cons: Node enters the build; same-address cookies make it tempting to
   skip proper API auth.
3. **Option 2, with the API designed as if the client were external.** Keeps option 2's
   simplicity and most of option 1's skills.

## Decision
- **Three slices, in order: 2a (accounts and "my occasions"), then 2b (the API), then 2c (the
  LINE front end and LINE Login).** Each gets its own design, spec and ADRs for the details.
- **warikan v1 becomes v2's LINE front end,** under its existing LIFF ID.
- **Its code moves into this repo as `liff/`** (with its git history, via `git subtree`) and
  is served from `warikan.lrod.dev/liff`. The old repo is archived with a pointer here. After
  2c there is one warikan.
- **The API is designed as if its client were external:**
  - **bearer tokens, never cookies.** The LIFF client exchanges LINE's ID token for an API
    token. No CSRF handling is needed, and any client (a mobile app, `curl`) works the same
    way;
  - **its own versioned namespace,** `/api/v1`, with controllers separate from the website's;
  - **explicit response shapes** (`jbuilder`, already in the Gemfile) instead of mirroring
    tables, including server-computed values such as shares;
  - **errors with machine-readable codes** as well as the Japanese message;
  - **correct HTTP semantics:** 201 with `Location`, 401, 404, 422, 429 with `Retry-After`;
  - **contract tests** (request specs pinning response shapes);
  - **no reliance on the shared address.** CORS isn't enabled; if the client ever moves to
    another origin, the only change is CORS configuration for that origin.

## Consequences
- **ADR 0003 is amended for 2c:** the Rails app stays Node-free, but the repo gains a Node
  build for the LIFF client only (a separate Docker build stage and CI job). A broken client
  build would also block Rails deploys; 2c's ADR decides how to contain that.
- **New gems** (e.g. for verifying LINE ID tokens) each need their own ADR in the slice that
  adds them.
- **2a alone covers Rails 8 auth,** the gap 0016 accepted, so phase 2 has value even if it
  stops after 2a.
- **API design is held by discipline, not a constraint:** nothing forces it to stay
  client-agnostic. The contract tests and this ADR are what keep it honest.
- **v1's name question (0017 update) is answered:** v1 doesn't get renamed; it becomes part of
  v2. Until 2c ships, docs keep calling them v1 and v2.
- **The LINE app's endpoint in LINE Developers changes to `warikan.lrod.dev/liff`** when 2c
  ships. That's a console setting, done by Luis.
