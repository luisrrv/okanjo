# Spec: move warikan v1 in and serve it at /liff (slice 2c-1)

- Status: Draft (2026-11-18)
- ADRs: 0003 (2026-11-18 update), 0017, 0021, 0024

## Goal
warikan v1's LIFF app lives in this repo as `liff/`, with its git history, and is served by
the Rails app at `https://warikan.lrod.dev/liff`. The LIFF app's endpoint URL points there.
**Users see no change:** the same calculator, the same ¥100 rounding, the same share card, and
v1's existing share links keep working. After this, there is one warikan in one repo and one
deploy.

## Out of scope (2c-2)
- LINE Login, `users.line_user_id`, account linking, any call to the API.
- Switching the calculator to ¥1 rounding and dropping the English mode (0024, D1 and D7).
- Any change to the website, the API or the domain model.

## Import
- `git subtree add --prefix=liff <path to the v1 repo> main`: one merge commit that brings in
  v1's 13 commits as its second parent. They keep their original paths (no `liff/` prefix), so
  `git log -- liff/` shows only the import; `git log <import commit>^2` shows v1's history.
- v1's `.env` is gitignored and stays behind. Nothing secret moves.

## Build
- **`liff/vite.config.ts`** (new): `base: '/liff/'`, so the built `index.html` references
  `/liff/assets/...`. v1 has no Vite config today; this is the only change to its code.
- **The LIFF ID** (`VITE_LIFF_ID`) is set with `ENV` in the Dockerfile's `liff` stage, the only
  place a production build happens. It's public (it's in every share link). A local hook blocks
  writing `.env` files, so it isn't in `liff/.env.production`.
- **`liff/package.json`:** add `"packageManager": "pnpm@<version>"`, so Corepack uses the same
  pnpm in Docker, CI and locally. The lockfile is format 9.0, which needs pnpm 9 or newer; the
  pnpm on Luis's Mac is 8.15.
- **Node 24** (the current LTS, and what's installed locally) in Docker and CI.

## Serving
`config.public_file_server.headers` gives every file in `public/` a one-year cache. That's right
for Vite's hashed assets and wrong for `index.html`: LINE would keep an old build for up to a
year. So the two are served differently:
- **Assets:** the Docker build copies `dist/` into `public/liff/`, except `index.html`. Hashed
  files under `public/liff/assets/` and v1's static files (`favicon.svg`, `og.png`, `qr.png`)
  get the existing long cache.
- **The page:** the build copies `dist/index.html` to `app/views/liff/show.html`, and
  `LiffController#show` renders it with `Cache-Control: no-cache`, so LINE revalidates on every
  launch.
- **`LiffController < ActionController::Base`,** not `ApplicationController`: no authentication,
  no `allow_browser` (LINE's in-app browser must never get a 406 here), no layout.
- **Route:** `get "liff", to: "liff#show"`. LINE opens the endpoint with extra query parameters
  (`liff.state` and v1's `total` and `people`); the page ignores them on the server, and the
  LIFF SDK and v1's code read them in the browser.
- **Not in git:** `public/liff/` and `app/views/liff/show.html` are build output, added to
  `.gitignore`. `liff/node_modules/` and `liff/dist/` go in `.gitignore` and `.dockerignore`.
- **Development:** `bin/dev` doesn't change. Working on the client uses Vite's dev server in
  `liff/` (`pnpm dev`) with v1's LIFF mock, as before.

## Docker
A build stage before the Ruby build:
```dockerfile
FROM docker.io/library/node:24-slim AS liff
WORKDIR /liff
RUN corepack enable
COPY liff/package.json liff/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY liff/ ./
RUN pnpm build
```
Then in the Ruby `build` stage, after `COPY . .`, copy `dist/` into `public/liff/` and
`dist/index.html` into `app/views/liff/show.html`. The final stage copies `/rails` as today, so
the image has the built files and no Node.

## CI
A `liff` job in `.github/workflows/ci.yml`: check out, set up Node 24, `corepack enable`,
`pnpm install --frozen-lockfile` and `pnpm build` (which runs `tsc` first) in `liff/`. Luis makes
it a **required check** for `main` in the repository settings; that's the containment 0024 chose.
No path filter: a required check that's skipped never reports, which blocks merges.

## The in-app browser check (before the endpoint switch)
`allow_browser versions: :modern` must not block website pages opened from LINE. Request specs
send LINE's in-app browser user agents (iOS and Android, current versions) to an occasion page
and expect `200`. If one gets `406`, the fix is decided before deploying.

## Luis's console tasks
1. Give the LIFF ID and the LINE Login channel ID that owns the LIFF app.
2. After 2c-1 is deployed and checked at `https://warikan.lrod.dev/liff` in a desktop browser:
   in the LINE Developers console, set the LIFF app's endpoint URL to
   `https://warikan.lrod.dev/liff`.
3. Make the `liff` CI job required for `main`.
4. Once verified in LINE: archive the v1 repo with a pointer to okanjo (its README), and retire
   the Netlify site after a grace period. Until then, switching the endpoint URL back is the
   rollback.

## Edge cases
- **v1's share links** (`liff.line.me/<LIFF ID>?total=…&people=…`) open the new endpoint with
  the same query string, so the calculator is prefilled as before.
- **The LIFF ID is missing at build time:** the build still succeeds (v1's check in `main.ts` runs
  in the browser), and the page would fail on launch. The Dockerfile always sets it.
- **A deploy while someone has the LIFF app open:** their page keeps its old assets (still on
  disk until Kamal's asset bridging drops them); the next launch loads the new `index.html`.
- **The `liff` build fails:** CI is red and the PR can't merge, so a broken client never reaches
  a deploy.

## Steps
1. **Import and build:** `git subtree add`, the Vite config, the LIFF ID, `packageManager`, and a local `pnpm build` in `liff/` that produces `dist/` with `/liff/`
   paths.
2. **Serve:** `LiffController`, the route, the ignores, the Docker stage; request specs for
   `/liff` and the in-app browser check.
3. **CI:** the `liff` job.
4. **Release:** deploy, check `/liff` in a desktop browser, Luis switches the endpoint URL,
   then check in LINE.

## Verification
1. `bundle exec rspec`, `bin/rubocop`, `bin/brakeman`; `pnpm build` in `liff/`.
2. Request specs: `/liff` returns `200` with `Cache-Control: no-cache` and the built page;
   LINE's user agents get `200` on an occasion page.
3. A local `docker build` produces an image with `public/liff/assets/*` and
   `app/views/liff/show.html`, and no `node` binary in the final stage.
4. **In production:** `/liff` and one asset return `200` with the right cache headers. After the
   endpoint switch, in LINE: the calculator works, sharing sends the card, and tapping an old
   shared card opens the calculator prefilled.
