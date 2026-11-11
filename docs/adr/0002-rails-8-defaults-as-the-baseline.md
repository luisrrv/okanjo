# 0002. Rails 8 defaults as the baseline

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
I last used Rails at 7.0 (2022). Rails 8 changed many defaults, and most of the changes
remove infrastructure: jobs, cache and Action Cable all run on the database instead of
Redis. An app built on 7.0-era choices would date its author to 2022, which is exactly the
impression to avoid with Rails shops.

## Options considered
1. **Rails 7.0-era stack:** Sidekiq and Redis, Sprockets, Devise,
   `params.require(...).permit(...)`, Heroku or Capistrano. Pros: familiar from the
   bootcamp. Cons: extra infrastructure, and it signals an out-of-date Rails.
2. **Rails 8 defaults:** Solid Queue, Solid Cache and Solid Cable on the database,
   Propshaft and importmap, the built-in auth generator, `params.expect`, Kamal 2. Pros:
   no Redis or Node, what current Rails shops expect, and generated code is the idiom.
   Cons: less familiar to me.

## Decision
Option 2. Use Rails 8 defaults unless an ADR says otherwise. Adding a gem needs an ADR.

## Consequences
- Infrastructure is the app server and SQLite. Solid Queue runs inside Puma (0017).
- Removed from the defaults (2026-11-11): `image_processing` and the `libvips` system package
  it drives. The app attaches no files and resizes no images, so they were unused; dropping
  them removed four gems and about 110 MB from the production image.
- Recorded deviations so far: RSpec and FactoryBot instead of Minitest and fixtures (0014),
  and the auth generator moving to phase 2 (0016).
- Reaching for a 7.0 habit (Sidekiq, Devise, Sprockets, `require/permit`, Heroku or
  Capistrano) gets flagged in review.
