# 0003. Hotwire monolith, not an API

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
The original warikan is a client-side LIFF app. I already know React and TypeScript well.
The rebuild exists to show Rails, and Tokyo Rails shops are overwhelmingly Hotwire
monoliths: a take-home is graded on ERB, partials and Turbo.

## Options considered
1. **`rails new --api` with a React front end.** Pros: familiar front-end territory. Cons:
   `--api` strips views, helpers, layouts, the asset pipeline and Hotwire. The effort goes
   into the half I already know, and the repo's interesting code ends up being
   TypeScript.
2. **A full-stack Rails app with Hotwire.** ERB views, layouts, partials, form helpers,
   Propshaft and importmap, Turbo and Stimulus. Pros: exercises the Rails a shop actually
   reviews, with no `package.json`, bundler or second process. Cons: a different mental
   model from React.

## Decision
Option 2: `rails new okanjo --css=tailwind`, with no `--api` and no JavaScript bundler.
Tailwind runs through `tailwindcss-rails`, which uses a standalone binary, so it doesn't
bring Node back. Tailwind over hand-written CSS is deliberate: the time goes to Rails, not
styling.

## Consequences
- No client-side state tree: the server returns HTML and Turbo swaps it in, and Stimulus
  adds behaviour to markup the server already rendered. State belongs in the database, not
  in JavaScript variables.
- Interactive pieces stay small, e.g. the Turbo Stream that updates balances and the
  Stimulus controller that confirms leaving the payer out of the split (0015).
- Phase 2 adds a JSON API next to the HTML app, for the LIFF client. The core keeps running
  on its own as a monolith.
