# okanjo · warikan (割り勘) on Rails 8

Split the bill for one occasion (a 飲み会, a trip), no sign-up needed. Create an occasion,
share the link, add who paid for what, and the app tells everyone who pays whom.

- **Live:** https://warikan.lrod.dev
- **UI language:** Japanese. Code, docs and commit history are in English.
- **okanjo** (お勘定, "the bill") is the codebase name. Users see it as **warikan**; this is
  warikan v2.

## Why it exists
I first built [warikan v1](https://github.com/luisrrv/warikan), a stateless LINE (LIFF)
calculator. It's still live: [open it in LINE](https://liff.line.me/2009905533-DGtLYpEl) or on the
[web](https://warikan.lrod.dev/liff). Its code now lives in this repo as `liff/`, with its history,
and this app serves it.
This repo is warikan v2: the same problem rebuilt as a Rails 8 Hotwire monolith with real
persistence. It's
the same domain in two stacks, and it shows how I design a system and ship it with AI: I
own the architecture and every decision, Claude Code implements from them, and the whole
trail is in this repo.

## Status
- **Core (live):** occasions, expenses, settlement, receipts and the 30-day purge, with CI,
  a Kamal deploy and Litestream backups.
- **Phase 2, slice 2a (live):** optional accounts.
- **Phase 2, slice 2b (live):** a versioned JSON API (`/api/v1`) designed as if its client
  were external. See [Try the API](#try-the-api).
- **Phase 2, slice 2c-1 (live):** warikan v1 moved into `liff/` and is served at `/liff`.
- **Phase 2, slice 2c-2 (live):** LINE Login, linking an email account, and the LIFF app's
  occasion screens on the API. There is now one warikan, on the web and in LINE. See [ADR 0021](docs/adr/0021-phase-2-shape.md) and
  [ADR 0024](docs/adr/0024-line-front-end-and-line-login.md).

## What it does
- **Occasions, not groups.** Every calculation is a new occasion, reached by an unguessable
  link. No login needed: a signed cookie remembers which member you are.
- **Optional accounts** (email and password, from the Rails 8 auth generator). Signing in
  links you to your member in each occasion and lists your occasions (自分の割り勘) on any
  device. Without an account, everything works the same.
- **Expenses** with one payer and an equal split. The payer can be left out of the split
  (e.g. a non-drinker paying the drinks tab), after a confirmation that states the effect in
  yen.
- **Shares round up, and the payer keeps the odd yen** (¥1,000 ÷ 3 = ¥334 each), so balances
  always sum to exactly zero.
- **Settle up through one collector (幹事):** the person owed the most collects from everyone
  and pays out the rest. That's at most n−1 transfers, chosen because people trust "pay the
  幹事" over a mathematically shorter but arbitrary pairing.
- **Live updates** for everyone viewing an occasion, without wiping what you're typing.
- **A printable receipt,** saved as a PDF from the browser.
- **Occasions are deleted 30 days after the last change** by a daily background job.
- **A JSON API** (`/api/v1`) that can do everything the website does with an occasion:
  bearer tokens, RFC 9457 errors, ETags, and an [OpenAPI description](docs/api/openapi.yaml).

## Design decisions
Every decision is recorded as an ADR in [`docs/adr/`](docs/adr/README.md), with the options
considered and their trade-offs. The system is summarised in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), with diagrams. Worth reading first:

| ADR | Decision |
|---|---|
| [0003](docs/adr/0003-hotwire-monolith-not-an-api.md) | A Hotwire monolith, not a JSON API with a React front end |
| [0008](docs/adr/0008-round-up-shares-computed-on-read.md) | Round each share up; compute shares on read, never store them |
| [0009](docs/adr/0009-where-the-split-logic-lives.md) | Per-expense logic on the model; the balance sheet and settlement as plain Ruby objects |
| [0013](docs/adr/0013-settle-through-a-collector.md) | Settle through a single collector: trust over the fewest transfers |
| [0016](docs/adr/0016-anonymous-core-with-30-day-retention.md) | No login in the core; 30-day retention; receipts |
| [0019](docs/adr/0019-live-refresh-with-turbo-broadcasts.md) | Live refresh with Turbo page-refresh broadcasts and morphing |
| [0021](docs/adr/0021-phase-2-shape.md) | Phase 2 in three slices: accounts, an external-grade API, then v1 as the LINE front end |
| [0022](docs/adr/0022-optional-accounts-with-the-auth-generator.md) | Optional accounts with the Rails 8 auth generator |
| [0023](docs/adr/0023-api-v1-for-slice-2b.md) | The API: a signed session id as the bearer token (and why not JWT), one aggregate read, problem details |
| [0024](docs/adr/0024-line-front-end-and-line-login.md) | v1 becomes the LINE front end: LINE's verify endpoint, account linking and merging, Node only in a build stage |

The feature specs written before each session are in [`docs/specs/`](docs/specs/).

## Stack
Rails 8.1 defaults throughout:
- SQLite, with Solid Queue, Solid Cache and Solid Cable (no Redis);
- Propshaft and importmap (no Node);
- Hotwire (Turbo 8 with morphing, and Stimulus);
- Tailwind through its standalone binary;
- RSpec and FactoryBot;
- Kamal 2 for the deploy.

The only gems beyond the defaults are `rspec-rails`, `factory_bot_rails` and `rails-i18n`,
each with an ADR.

## Run it locally
Needs Ruby 3.4.10 (see `.ruby-version`) and Chrome for the system specs.

```bash
bin/setup        # installs gems, creates and seeds the database (a sample 飲み会)
bin/dev          # http://localhost:3000, with Tailwind rebuilding on change
bundle exec rspec
bin/ci           # everything CI runs: RuboCop, security audits, specs
```

## Try the API
Every endpoint is in [`docs/api/openapi.yaml`](docs/api/openapi.yaml). With `bin/dev` running,
create an account at http://localhost:3000/registration/new, then (with `jq` installed):

```bash
API=http://localhost:3000/api/v1

# Sign in: the token is valid for 30 days, or until you sign out
TOKEN=$(curl -s $API/session -H 'Content-Type: application/json' \
  -d '{"email_address":"you@example.com","password":"your-password"}' | jq -r .token)
AUTH="Authorization: Bearer $TOKEN"

# Create an occasion; you're its first member
OCCASION=$(curl -s $API/occasions -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name":"飲み会","member_name":"Aki"}' | jq -r .token)
AKI=$(curl -s $API/occasions/$OCCASION -H "$AUTH" | jq .my_member_id)
BEN=$(curl -s $API/occasions/$OCCASION/members -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name":"Ben"}' | jq .id)

# ¥1,001 split two ways: ¥501 each, and Aki keeps the odd yen
curl -s $API/occasions/$OCCASION/expenses -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"description\":\"1次会\",\"amount\":1001,\"payer_id\":$AKI,\"member_ids\":[$AKI,$BEN]}"

# The whole occasion: balances and who pays whom, worked out on the server
curl -s -D - $API/occasions/$OCCASION -H "$AUTH"

# Ask again with the ETag from that response: 304, nothing loaded
curl -s -o /dev/null -w '%{http_code}\n' $API/occasions/$OCCASION -H "$AUTH" -H 'If-None-Match: <ETag>'

# Sign out: the token stops working
curl -s -X DELETE $API/session -H "$AUTH"
```

The occasion is also on the website at `http://localhost:3000/groups/$OCCASION`, and a page
open there refreshes when the API changes it.

## How it was built
The design came first, then one feature at a time, each following the same workflow:
1. **Options:** 2–3 approaches with trade-offs.
2. **Decision:** made by me and recorded as an ADR.
3. **Spec:** written before any code.
4. **Implementation:** small, reviewable commits, each with tests.

[`docs/WORKING_AGREEMENT.md`](docs/WORKING_AGREEMENT.md) holds the working agreement. Claude's
own configuration files are kept local and aren't committed. A few commits are worth reading as
a pair:
- `f62f874` and `062f440`: a deliberately naive balance sheet with an N+1 (37 queries on the
  sample data, 197 in a larger spec), then the fix (3 queries) and a spec that keeps it fixed.
- `d1d81d8`: a real incompatibility between `activesupport` 8.1.3.1 and `json` 3.0, found
  when the first signed cookie was read, and fixed by a Rails patch update instead of a pin.
