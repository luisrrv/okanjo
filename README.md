# okanjo · warikan (割り勘) on Rails 8

Split the bill for one occasion (a 飲み会, a trip) without signing up. Create an occasion,
share the link, add who paid for what, and the app tells everyone who pays whom.

- **Live:** https://warikan.lrod.dev (deploy in progress)
- **UI language:** Japanese. Code, docs and commit history are in English.
- **okanjo** (お勘定, "the bill") is the codebase name. Users see it as **warikan**.

## Why it exists
I built [warikan](https://github.com/luisrrv/warikan) as a stateless LINE (LIFF) calculator.
okanjo rebuilds the same problem as a Rails 8 Hotwire monolith with real persistence. It's
the same domain in two stacks, and it shows how I design a system and ship it with AI: I
own the architecture and every decision, Claude Code implements from them, and the whole
trail is in this repo.

## What it does
- **Occasions, not groups.** Every calculation is a new occasion, reached by an unguessable
  link. There's no login. A signed cookie remembers which member you are.
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

## How it was built
The design came first, then one feature at a time, each following the same workflow:
1. **Options:** 2–3 approaches with trade-offs.
2. **Decision:** made by me and recorded as an ADR.
3. **Spec:** written before any code.
4. **Implementation:** small, reviewable commits, each with tests.

The project's [`CLAUDE.md`](CLAUDE.md) holds the working agreement. A few commits are worth
reading as a pair:
- `f62f874` and `062f440`: a deliberately naive balance sheet with an N+1 (37 queries on the
  sample data, 197 in a larger spec), then the fix (3 queries) and a spec that keeps it fixed.
- `d1d81d8`: a real incompatibility between `activesupport` 8.1.3.1 and `json` 3.0, found
  when the first signed cookie was read, and fixed by a Rails patch update instead of a pin.
