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
- ~~Open: the hosting provider, and paid versus free.~~ Decided below.

## Update (2026-11-02): hosting
Luis wants the least cost for a portfolio project, as long as it stays workable. Prices
checked on the providers' own pages: Sakura VPS 1 GB is 990円/month in Tokyo and 880円 in
Ishikari; Lightsail 1 GB is $7/month. Running the purge job more often doesn't change the
cost of a fixed-price VPS.

**Decision: a server in Japan, free tier first.**
- **First choice: Oracle Cloud Always Free, ARM, Tokyo or Osaka (0円).** Kamal builds for
  `arm64`, which Luis's Apple Silicon Mac does natively, so deploys are fast. Known
  friction: sign-up approval and regional capacity are unreliable, idle free servers can be
  reclaimed (upgrading to pay-as-you-go while staying in the free limits is the usual fix;
  to verify in Oracle's docs), and ports 80/443 must be opened in both the security list
  and the server's own firewall.
- **Fallback: Sakura VPS, Ishikari, 1 GB (880円/month).** The cheapest paid option with
  enough memory; still in Japan. The image is then built for `amd64` on the Mac
  (emulated, slower). Switching is a `config/deploy.yml` change plus one DNS record.
- Not chosen: Sakura Tokyo 1 GB (990円, 110円 more for no visible difference), Sakura 512 MB
  (698円, too little memory), Lightsail (about the same price, billed in USD), and PaaS free
  tiers (their disks are wiped on deploy, which loses SQLite).
- Buying the server and adding the Gandi DNS record are done by Luis; Claude prepares the
  Kamal configuration and runs deploys with his OK.

## Update (2026-11-13): first deploy, and the registry
- **Capacity:** Oracle's free ARM shape was "out of host capacity" in Osaka for several days
  of retries. Upgrading the account to pay-as-you-go (Always Free resources stay free, with
  a 0円 budget alert) got a server on the first apply.
- **Registry: GitHub Container Registry, not Kamal's local registry.** With the local
  registry, the server pulls the image back through an SSH tunnel run by `net-ssh` on the
  Mac. Pulling about 500 MB of layers in parallel through it failed twice, inside `net-ssh`'s
  socket writes (`IOError: closed stream`, then `Errno::ERANGE`). The tunnel itself worked in
  isolation, so it broke under load. `ghcr.io/luisrrv/okanjo` removes the tunnel: the server
  pulls over HTTPS.
  - The image is public. The repo is public and the image holds no secrets:
    `RAILS_MASTER_KEY` is only given to the container at start, and the credentials file
    inside it is encrypted.
  - Kamal authenticates with a classic GitHub token (`write:packages` only, 90-day expiry),
    read from the macOS keychain by `.kamal/secrets`. It is also stored by `docker login` on
    the server for the `ubuntu` user.
- **A long first build can reset Kamal's idle SSH connection** to the server (about 9 minutes
  idle during a cold build). Re-running with cached layers succeeded in 58 seconds.
- **Still open:** database backups for the SQLite volume, and the Netlify redirect from the
  old app.

