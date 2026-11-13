# Spec: database backups with Litestream

- Status: Implemented (2026-11-13)
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

## How to restore for real

**Tested (2026-11-13), the restore drill:** restoring the latest backup into a separate file
inside the running container, then comparing it with the live database:

```bash
bin/kamal app exec --reuse 'bash -c "bundle exec litestream restore -config config/litestream.yml -o /tmp/restore-drill.sqlite3 storage/production.sqlite3 && sqlite3 /tmp/restore-drill.sqlite3 \"PRAGMA integrity_check\""'
```

The restored copy matched the live database row for row, including a change made about a
minute before the restore, which shows ongoing changes are backed up, not just the daily
snapshot.

**Restoring over the live database** (not run, since it means stopping production; steps 1
and 3 are standard Kamal commands, step 2 uses the tested restore command with the live
path):
1. `bin/kamal app stop`: the app stops, and the volume and its files stay.
2. Keep the broken file, then restore in a one-off container (same image, environment and
   volume):
   ```bash
   bin/kamal app exec 'bash -c "mv storage/production.sqlite3 storage/production.sqlite3.broken && rm -f storage/production.sqlite3-wal storage/production.sqlite3-shm && bundle exec litestream restore -config config/litestream.yml -o storage/production.sqlite3 storage/production.sqlite3"'
   ```
   Moving the old file aside first means the restore never writes over data, and the broken
   copy is kept for investigation. Delete it once the restored database is confirmed.
3. `bin/kamal app boot`, then check `/up` and an occasion page.

## Follow-ups
- Alert if replication stops, e.g. a recurring job that checks the last upload time.
- Revisit the 1-minute sync and 7-day retention if traffic grows.
