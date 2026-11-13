# 0020. Back up the database with Litestream

- Status: Accepted
- Date: 2026-11-13
- Decider: Luis

## Context
Production data is one SQLite file (`storage/production.sqlite3`) on one Docker volume on one
server (0017). A bad migration, a mistaken command or a lost server would lose every active
occasion with no way back. Occasions only live 30 days and people can keep receipts (0016), so
a loss is annoying rather than catastrophic, but a showcase without backups is a red flag.

The Oracle account is pay-as-you-go, with Always Free resources: Object Storage with 10 GB in
the standard tier and 50,000 API requests a month at no charge.

## Options considered
1. **Litestream to Oracle Object Storage.** The `litestream` gem streams every change to a
   bucket and restores from it. Pros: about a minute of data at risk, the standard approach for
   SQLite in production, mostly configuration. Cons: a gem, a credential pair, a process inside
   Puma, and API requests counted against the free limit.
2. **A nightly snapshot uploaded to Oracle.** A Solid Queue job runs `VACUUM INTO` and uploads
   the copy. Pros: simple to reason about. Cons: up to 24 hours at risk, a gem for the upload,
   and more of our own code than option 1.
3. **A nightly snapshot kept on the same server.** Pros: no gem. Cons: no protection if the
   server is lost.
4. **No backups.** Pros: nothing to run. Cons: everything lost on any failure.

## Decision
Option 1: the `litestream` gem, replicating the primary database to a private bucket in
Oracle Object Storage (Osaka) through its S3-compatible API.

- **Only the primary database.** The cache, queue and cable databases hold nothing that can't
  be rebuilt.
- **Sync every minute,** not Litestream's default of every second. That's at most about 43,000
  uploads a month even if the app wrote continuously, under the 50,000 free requests. About a
  minute of changes is at risk.
- **Keep backups for 7 days.** Occasions are deleted 30 days after the last change (0016);
  longer backups would keep purged occasions alive. With 7 days, a purged occasion is gone from
  backups a week later.
- **A restore drill is part of done.** A backup that has never been restored is a guess.

## Consequences
- One more gem (this ADR), running inside Puma in production through its plugin.
- An Oracle bucket and a storage key pair ("Customer Secret Key"), created by Luis. The keys
  are read from the macOS keychain by `.kamal/secrets`, like the registry token, and passed to
  the container as environment variables. They never go in a file or the repo.
- The 0円 budget alert (0017) would catch any unexpected storage charges, a day later.
- The upload frequency and the retention are a trade-off between request costs, data at risk
  and privacy. Revisit them if traffic grows.
- Restoring means stopping the app, running `bin/rails litestream:restore` into the volume, and
  starting it again. The spec has the exact steps, tested once.
