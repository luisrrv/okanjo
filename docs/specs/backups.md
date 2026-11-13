# Spec: database backups with Litestream

- Status: Draft
- ADRs: 0016, 0017, 0020

## Goal
Every change to the production database reaches a private Oracle bucket within about a minute,
backups older than 7 days are deleted, and a restore has been done once and checked.

## Out of scope
- Backing up the cache, queue and cable databases.
- Point-in-time restore tooling beyond what Litestream provides.
- Alerting when replication stops (noted under follow-ups).

## Luis creates (Oracle console)
1. **A bucket:** Object Storage → Buckets → Create Bucket. Name `okanjo-backups`, compartment
   `lurodv (root)`, **Standard** tier, visibility private (the default), no auto-tiering.
2. **A storage key pair:** profile icon → your username → **Customer secret keys** →
   **Generate secret key**, named `okanjo-litestream`. It shows an **access key** and a
   **secret key**. The secret is shown only once.
3. **Store both in the macOS keychain** with the clipboard method that worked for the registry
   token:
   - `security add-generic-password -U -a "$USER" -s okanjo-litestream-access-key -w "$(pbpaste)"`
   - `security add-generic-password -U -a "$USER" -s okanjo-litestream-secret-key -w "$(pbpaste)"`
   - then `pbcopy < /dev/null`.
4. **The Object Storage namespace:** a short string shown on the bucket page or under Tenancy
   details. It's part of the endpoint URL and isn't secret.

## Claude implements
- **Gem:** `litestream`, which bundles the Litestream binary for each platform. Check its
  current version and config format at install time: Litestream 0.5 changed the config file
  compared to 0.3.
- **Config:** `config/litestream.yml`, production only.
  - The primary database `storage/production.sqlite3`.
  - One S3 replica:
    - bucket `okanjo-backups`, path `production`;
    - endpoint `https://<namespace>.compat.objectstorage.ap-osaka-1.oraclecloud.com`, region
      `ap-osaka-1`, with path-style requests;
    - sync interval 1 minute, retention 168 hours (7 days), a snapshot every 24 hours.
  - The keys come from environment variables.
- **Run it:** the gem's Puma plugin, enabled only in production, next to Solid Queue.
- **Secrets:**
  - `.kamal/secrets` reads the two keys from the keychain;
  - `config/deploy.yml` adds them to `env.secret`;
  - the namespace and bucket go in `env.clear`.
- **CI and tests:** nothing replicates in development or test. A spec checks that the
  production config points at the primary database, with a 7-day retention and a 1-minute sync,
  so a careless edit can't quietly change them.

## Verification
1. **After deploy:**
   - the app logs show Litestream replicating `production.sqlite3`;
   - the bucket shows objects under `production/` within a minute or two.
2. **Restore drill:**
   - restore the latest backup **into a separate file** on the server
     (`bin/rails litestream:restore` with an output path), never over the live database;
   - compare row counts for groups, members, expenses and participations with the live
     database. They should match, allowing for about a minute of new writes.
   - Then delete the copy.
3. **Request count:** after a day, check the bucket's request metrics or the cost report, to
   confirm the free 50,000 requests a month are not at risk.
4. `bundle exec rspec`, `bin/rubocop`, `bin/brakeman`.

## How to restore for real (written into the README or a runbook)
1. `bin/kamal app stop`.
2. Restore over `storage/production.sqlite3` with `bin/rails litestream:restore`, through
   `bin/kamal app exec`.
3. `bin/kamal app boot`.
4. Check `/up` and an occasion page.

The exact commands get filled in from the restore drill, so they're commands that have
actually run.

## Follow-ups
- Alert if replication stops, e.g. a recurring job that checks the last upload time.
- Revisit the 1-minute sync and 7-day retention if traffic grows.
