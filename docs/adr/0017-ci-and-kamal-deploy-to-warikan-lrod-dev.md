# 0017. CI, and a Kamal deploy to warikan.lrod.dev

- Status: Accepted
- Date: 2026-10-20
- Decider: Luis

## Context
The core roadmap includes CI and a Kamal deploy. The original plan only said "push public,
dated". `rails new` already generated a GitHub Actions workflow and a placeholder
`config/deploy.yml`.

Phase 2 will ship (0016), and it needs a public HTTPS URL: a LIFF app is served from one,
and LINE Login needs an HTTPS callback. The app needs a long-running Puma process, a disk
that survives restarts (SQLite) and the Solid Queue purge job (0012), so a static host
like Netlify, where the original warikan lives, can't run it.

The original LIFF app (warikan-jp.netlify.app) will be retired once this one ships.

## Options considered
1. **CI plus a Kamal deploy to a VPS, as the last step of the core.** Pros: a live URL for
   reviewers, Kamal is the Rails 8 deploy story, and phase 2 needs the deploy anyway.
   Cons: a monthly cost and a server to keep patched.
2. **CI only, no deploy in the core.** Pros: no cost, no server. Cons: no live demo, and
   the deploy work moves into phase 2 alongside the LINE setup.
3. **A PaaS** (Render, Fly.io, Heroku). Pros: less server work. Cons: drops a Rails 8
   default (Heroku is a Rails 7.0 habit), and many PaaS disks are wiped on each deploy,
   which breaks SQLite.

## Decision
Option 1.

- **CI:** keep the generated workflow (Brakeman, bundler-audit, the importmap audit,
  RuboCop, tests and system tests). Switch the two test jobs to RSpec (0014) when it's
  installed.
- **Deploy:** Kamal 2 to a VPS in Tokyo, as the last step of the core. Tokyo because the
  users are in Japan and Turbo makes many small requests. Whether to pay (about ¥1,000 a
  month) or use a free tier, and which provider, is decided at the deploy step.
- **Domain:** `warikan.lrod.dev`, an A record in Gandi DNS pointing at the server. Gandi
  doesn't proxy traffic, so Let's Encrypt works without extra setup.
- **Name:** warikan (割り勘) is the product name users see in the page title, header and
  receipt. okanjo stays the codebase name: the repo, the `Okanjo` module, the database
  names and `service: okanjo` in Kamal. The old app's name is free because it's being
  retired.

## Consequences
- `.dev` domains are HTTPS-only in every browser (HSTS preload). Kamal's proxy must have
  SSL on from the first deploy (`proxy: ssl: true, host: warikan.lrod.dev`), and port 80
  must stay open for Let's Encrypt.
- The generated config uses Kamal's local registry, which pushes the image over SSH, so no
  external registry is needed.
- `SOLID_QUEUE_IN_PUMA: true` is already set, so the purge job runs in the web process:
  one server, one container.
- SQLite lives on a Docker volume. Occasions only last 30 days (0016), so losing data is
  less of a risk than usual, but a simple backup is still worth adding.
- Anyone can create occasions without logging in, so controllers that create records get
  a `rate_limit` (built into Rails 8) against spam.
- Phase 2 can serve the LIFF client from a path on the same domain (e.g. `/liff`), so it
  shares session cookies with the web app. To be settled in the phase 2 ADR.
- The README presents the old LIFF app as the predecessor and links to its repo.
- Follow-up once this ships: a Netlify `_redirects` rule in the old repo sending
  warikan-jp.netlify.app to warikan.lrod.dev.
- Open: the hosting provider, and paid versus free.
