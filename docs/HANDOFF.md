# Handoff

The state of the work for whoever picks it up next: a new Claude Code session (terminal, phone,
cloud) or Luis. Read this first. It only holds what the other docs don't; it links to them for
the rest.

_Last updated: 2026-11-27._

## Current state
- **Branch:** `claude/handoff-ruby-upgrade` (from `main` at `1cef9e5`), docs only, waiting for
  Luis's review: it records the Ruby upgrade, the gem updates and the Capybara workaround.
- **Claude config is local only.** `CLAUDE.md`, `CLAUDE.local.md` and `.claude/` are ignored by
  the global `~/.config/git/ignore` on Luis's Mac. A fresh clone has none of them;
  `CLAUDE.local.md` imports the public agreement with `@docs/WORKING_AGREEMENT.md`.
- **Live at https://warikan.lrod.dev:** the core (phase 1) and all of phase 2 (ADR 0021): optional
  accounts (2a), the JSON API at `/api/v1` (2b), and the LINE front end at `/liff` with LINE Login
  and account linking (2c). Production runs `1cef9e5` (deployed 2026-11-27): Ruby 3.4.13,
  puma 8.1.3.
- **Verified in production:** each slice's spec has a "Verified in production" section
  (`docs/specs/accounts.md`, `api.md`, `liff-move.md`, `line-login.md`).
- **warikan v1** (`luisrrv/warikan`) is archived with a pointer here; its code lives in `liff/`
  with its history (`git log 6542727^2`). The LIFF endpoint points at
  `https://warikan.lrod.dev/liff`.
- **The LINE Login channel (ID 2009905533) is still "Developing":** only its admins and testers
  can sign in with LINE.

## Next steps (in priority order)
1. **Phase 3, security and limits:** a design round (options and tradeoffs per item), Luis's
   decisions, then ADR 0025 and specs. Candidates and reasoning: `docs/ARCHITECTURE.md`,
   "Phase 3". Start with the per-address limit on password resets, the CSP, the privacy policy
   page (then publish the LINE channel) and the session purge.
2. **The write-up ADR 0021 promised:** `docs/` "Adding LINE to an existing Rails app" (LINE
   channel setup, verifying the ID token on the server, account linking, the in-app browser,
   what the core didn't need).
3. **Interview practice:** a round on 2c (e.g. why `create_or_find_by!` conflicts with a
   uniqueness validation; why LINE's verify endpoint instead of decoding the JWT; how the merge
   stays safe). The questions and answers so far are kept in Luis's private notes, outside
   this repo.
4. **Smaller follow-ups:** a per-occasion rounding unit (¥1/¥10/¥100, ADR 0024 D1); a test runner
   for `liff/`; a native-speaker review of the Japanese in `config/locales/ja.yml` `api.errors` and
   `liff/src/i18n.ts`; the open Dependabot PRs (`bootsnap`, `thruster`, `selenium-webdriver`,
   `actions/setup-node`).

## Decisions not recorded in an ADR
Most decisions are ADRs (`docs/adr/README.md`). These smaller ones were made while building:
- **2026-11-16** Active Storage, Action Text and Action Mailbox aren't loaded (`rails/all` replaced
  by explicit requires). Recorded as a dated note in ADR 0002.
- **2026-11-17** Each step ships as its own branch and PR from `main`, merged by Luis, then
  deployed by Kamal from `main`. Docs-only "mark live" PRs follow each production check.
- **2026-11-17** `amount: "3000"` (a whole number as a string) is accepted exactly; decimals are
  `422`. Rails casts it; nothing is rounded (`docs/specs/api.md`).
- **2026-11-18** The `liff/` subtree PR had to be merged with a merge commit; squash or rebase
  would have dropped v1's history.
- **2026-11-18** The LIFF page (`index.html`) is served by `LiffController` with `no-cache`; only
  hashed assets live in `public/liff` (which gets a one-year cache).
- **2026-11-18** No uniqueness validation on `users.line_user_id`: the unique index is the guard,
  because a validation turns `create_or_find_by!`'s race into `RecordInvalid`.
- **2026-11-18** The LIFF app never creates an account on its own; only tapping
  「LINEでログイン」 does.
- **2026-11-18** Oracle charges of about ¥2 a month are acceptable (likely Litestream's Object
  Storage requests; unconfirmed). Keep the 1-minute sync; raise the alert instead.
- **2026-11-27** Real Oracle spend is about ¥7–8 a month (¥7.38 spent, ¥8.10 forecast on
  2026-11-27), not ¥2. Budget `okanjo-no-charges` raised from ¥1 to ¥20, with alerts at
  Forecast 100% (¥20), Actual 100% (¥20) and Actual 1000% (¥200); the ¥1 rule is gone.
- **2026-11-27** The Netlify project `warikan-jp` is disabled, not deleted, so nobody else can
  claim `warikan-jp.netlify.app`. The 2c rollback to Netlify is gone (ADR 0024 update).

- **2026-11-20** Claude config files are never committed, okanjo included. `CLAUDE.md`,
  `.claude/settings.json`, `.claude/hooks/verify.sh` and the `/adr` skill are untracked (kept
  locally; old commits still have them). The agreement is now `docs/WORKING_AGREEMENT.md`
  (ADR 0001 update). `docs/HANDOFF.md` is now committed.
- **2026-11-27** Ruby 3.4.10 → 3.4.13 for CVE-2026-132825 (a heap overflow in string case
  conversion, fixed 2026-11-18), found when Brakeman 8.1.1 flagged it. puma 8.1.1 → 8.1.3 and
  net-ssh 7.3.8 → 7.3.10 for `bundler-audit` advisories. Deployed the same day.
- **2026-11-27** Chrome 158 broke Capybara's `reset!` in CI and locally. Worked around in
  `spec/support/` rather than pinning Chrome in CI, so local runs pass too. `selenium-webdriver`
  4.54 didn't help.

## Gotchas
- **Remote and GitHub CLI:** the remote is `origin2`, not `origin`. `git push` works over SSH as
  `luisrrv`, but `gh` on this Mac is signed in to another account that isn't a collaborator:
  `gh pr create` fails.
  Open PRs from `https://github.com/luisrrv/okanjo/compare/main...<branch>?expand=1`. `gh` can
  still read public PRs and CI (`gh pr checks`, `gh run list`).
- **`VITE_LIFF_ID` must be set for any production build of `liff/`.** Without it Vite turns
  `main.ts`'s guard into an unconditional `throw` and drops the whole app, silently (a ~2 KB
  bundle). The Dockerfile and the CI `liff` job set it; set it for local builds too.
- **A local hook blocks writing `.env*` files**, which is why the LIFF ID lives in the Dockerfile.
- **`bin/rails runner '…'` with Japanese text fails** (`Encoding::UndefinedConversionError`):
  inline code arrives as binary. Put the code in a `.rb` file and run that.
- **zsh doesn't split unquoted variables** (`for x in $LIST` runs once); use arrays or one
  command per item.
- **Kamal's "Error preparing clone"** at the start of a deploy is harmless: its cached build clone
  is stale, so it deletes it and clones again.
- **The website returns `406` to `curl`** (`allow_browser versions: :modern`). Expected; LINE's
  in-app browser passes (`spec/requests/liff_spec.rb`). The API and `/liff` don't use it.
- **Checking production:** `bin/kamal app exec --reuse 'bin/rails runner "…"'` and
  `bin/kamal app logs --since 1h`. A fake ID token at `POST /api/v1/session/line` should get
  `401 invalid_line_token`: proof the server reaches LINE with the right channel.
- **Testing the LIFF client locally:** the mock can't sign in (the server checks tokens with
  LINE). Create a token with a runner script and put it in `localStorage`; see
  `liff/src/liff-mock.ts`. Run Rails on 3000 and `pnpm dev` in `liff/` (it proxies `/api`).
- **pnpm:** `liff/` pins pnpm 10 via `packageManager`; run `corepack enable` once (the global pnpm
  on Luis's Mac is 8.15 and can't read the lockfile).
- **`spec/support/capybara_chrome_158.rb` is temporary.** Chrome 158 rejects the `*` origin that
  Capybara 3.40.0 sends from `reset!`, so every system spec failed in teardown. Delete the file
  once a Capybara release fixes it
  ([teamcapybara/capybara#2865](https://github.com/teamcapybara/capybara/issues/2865)).
- **`bin/brakeman` runs with `--ensure-latest`** (kept on purpose): CI's `scan_ruby` fails as
  soon as a new Brakeman is released, until `Gemfile.lock` is updated. The same job runs
  `bundler-audit`, which fails on any new gem advisory.
- **The 2026-11-27 deploy took 78 minutes** (normally a few). Likely the first build on a new
  Ruby base image (no cache, every native gem recompiled, all layers pushed), but the build log
  wasn't kept. Keep the full log next time: `bin/kamal deploy 2>&1 | tee tmp/deploy.log`.

## Open questions
- **The Oracle charge's SKU** (Cost Analysis, grouped by service and SKU) is unconfirmed.
- **Native-speaker review** of the new Japanese copy (see next step 4).
- **The privacy policy's wording** for publishing the LINE channel is Luis's.
- **The desktop app's worktree** `.claude/worktrees/eloquent-mendel-a87f71` (detached at `main`,
  clean) can be removed: `git worktree remove .claude/worktrees/eloquent-mendel-a87f71`.

## Where things live
- `README.md`: what the app does, status, stack, running it, and a `curl` walkthrough of the API.
- `docs/ARCHITECTURE.md`: system context, domain model, key flows (incl. the API and LINE
  sign-in), deployment and CI, phase 2, and the planned phase 3. Mermaid diagrams.
- `docs/adr/README.md`: the index of every decision (0001–0024).
- `docs/specs/`: one spec per feature or slice, written before the code; each ends with what was
  verified in production.
- `docs/api/openapi.yaml`: the API, by hand (15 operations), pinned by `spec/requests/api/v1/`.
- `docs/specs/backups.md`: Litestream and the restore runbook.
- `liff/`: the LINE (LIFF) client, vanilla TypeScript; `liff/src/liff-mock.ts` for local work.
