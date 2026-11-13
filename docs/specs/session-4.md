# Spec: receipt, purge job, README, deploy (session 4)

- Status: Implemented (2026-11-13); live at https://warikan.lrod.dev
- ADRs: 0012, 0016, 0017 (hosting update), 0018
- Depends on: [settlement](settlement.md)

## Goal
Finish the core: a printable receipt for each occasion, the 30-day purge job, a README that
explains the design, and a deploy to `warikan.lrod.dev`.

## Out of scope
- Phase 2 (auth generator, JSON API, LIFF, LINE Login).
- A friendly page for a deleted occasion (still Rails' standard 404).
- Database backups beyond the Docker volume (noted for after the deploy).

## 1. Receipt (ADR 0016)
- **Route:** `resource :receipt, only: :show` nested under the group:
  `GET /groups/:token/receipt`.
- **Content:**
  - the occasion's name (or creation date) and the date the receipt was printed;
  - every expense, oldest first: description, amount, payer, who was in the split, and the
    share each;
  - the total spent;
  - each member's balance, then the transfers through the collector;
  - a footer naming the app and its URL.
- **Printing:** a 印刷・PDFで保存 button calls `window.print()` (a tiny Stimulus `print`
  controller). The layout's header, flash messages and the button are hidden on paper
  (Tailwind `print:hidden`). The browser's "Save as PDF" produces the file, with no gems.
- **Link:** from the occasion page, next to the title.
- **Queries:** the expenses are loaded with payers and participations' members preloaded,
  so the query count stays the same whatever the size.

### Copy

Revised after the native-speaker review (2026-11-11). `config/locales/ja.yml` is the source of
truth; this table is the original draft.

Glosses are in English. A native speaker should review it before launch.

| Key | Japanese | English gloss |
|---|---|---|
| `groups.show.receipt_link` | 明細を印刷 | Print the statement |
| `receipts.show.title` | 割り勘の明細 | Bill-splitting statement |
| `receipts.show.printed_on` | 発行日：%{date} | Issued: %{date} |
| `receipts.show.print` | 印刷・PDFで保存 | Print / save as PDF |
| `receipts.show.back` | 戻る | Back |
| `receipts.show.expenses` | 支払い一覧 | Payments |
| `receipts.show.paid_by` | 支払い：%{payer}さん | Paid by %{payer} |
| `receipts.show.split_among` | 割り勘：%{names}（1人 %{share}） | Split among %{names} (%{share} each) |
| `receipts.show.total` | 合計 | Total |
| `receipts.show.settlement` | 精算 | Settle up |
| `receipts.show.empty` | 支払いはありません | No payments |
| `receipts.show.footer` | 割り勘（%{url}）で作成 | Made with warikan (%{url}) |

Names in `split_among` each get さん and are joined with 、 (as in the payer-split
confirmation).

## 2. Purge job (ADR 0012, 0016)
- `PurgeStaleGroupsJob#perform`: `Group.where(updated_at: ...Group::RETENTION.ago).delete_all`,
  relying on the database cascades. A comment says it deliberately skips callbacks. It logs
  how many occasions it deleted.
- `config/recurring.yml`, production: `every day at 4am Asia/Tokyo`. Solid Queue runs
  inside Puma (`SOLID_QUEUE_IN_PUMA`).
- **Behaviour:** an occasion is never deleted before the date its page shows. A missed run
  catches up the next day, because the query is "older than 30 days".
- **Specs:** deletes occasions untouched for more than 30 days, with all their members,
  expenses and split entries; keeps recent ones; keeps one exactly at the boundary; a change
  (e.g. adding an expense) resets the clock.

## 3. README
- Replace the Rails boilerplate:
  - what the app is, with the live link;
  - the same problem in two stacks, linking the old LIFF app as its predecessor;
  - a short tour of the key decisions, linking the ADRs;
  - how to run it locally (`bin/setup`, `bin/dev`, `bundle exec rspec`);
  - the AI-assisted workflow (ADR 0001).
- Written in English (0018); the app's UI is Japanese.

## 4. Deploy (ADR 0017)
- **Luis:** create the Oracle account and an Always Free ARM instance (Ubuntu) in Tokyo or
  Osaka; add the SSH public key; add an A record `warikan` in Gandi. If Oracle doesn't work
  out, the same steps on Sakura VPS Ishikari 1 GB.
- **Claude:** `config/deploy.yml` (server IP, `proxy: ssl: true, host: warikan.lrod.dev`,
  builder `arch: arm64`, or `amd64` for Sakura), `.kamal/secrets` reading `RAILS_MASTER_KEY`
  without committing it, and the exact firewall steps for Oracle (security list plus the
  server's own firewall rules for ports 80 and 443).
- **Prepared ahead (2026-11-11):** `config/deploy.yml` has `proxy: ssl: true, host:
  warikan.lrod.dev`, `builder: arch: arm64` and `ssh: user: ubuntu` with
  `~/.ssh/okanjo_deploy`. Production enables `assume_ssl`, `force_ssl` (except `/up`) and
  `config.hosts = ["warikan.lrod.dev"]`. Only the server IP placeholder remains.
  - Checked locally: the production image builds natively on the Mac (about 6 minutes from
    cold) and starts. `/up` returns 200; the start page returns 200 for `warikan.lrod.dev`
    and 403 for any other host; the Tailwind and JS assets are served; `db:prepare` creates
    all four SQLite databases with no seed data; Solid Queue starts inside Puma with
    `purge_stale_groups` scheduled.
- **Server bootstrap (once, before `kamal setup`).** Kamal connects as `ubuntu`, not root,
  so Docker must already be installed:
  1. Oracle console: `okanjo-vcn` → **Security Lists** → *Default Security List* → **Add
     Ingress Rules**: source `0.0.0.0/0`, TCP, destination port `80`, and the same for
     `443`. Port 22 is already open.
  2. On the server (`ssh -i ~/.ssh/okanjo_deploy ubuntu@<IP>`), Oracle's Ubuntu image also
     blocks ports in its own firewall:
     `sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT`, the same
     for `443`, then `sudo netfilter-persistent save`.
  3. Install Docker and let `ubuntu` use it:
     `curl -fsSL https://get.docker.com | sudo sh` and `sudo usermod -aG docker ubuntu`,
     then log out and back in.
  4. Gandi: an A record `warikan` → the server's IP. Let's Encrypt needs it to resolve
     before the first deploy, or the certificate request fails.
  5. Replace the IP placeholder in `config/deploy.yml`.
  - Sakura fallback: the same steps, minus step 1 (Sakura has no security list by default;
    check its packet filter setting), and set `builder: arch: amd64`.
- **First deploy:** `bin/kamal setup`, run with Luis's OK. Check: HTTPS works, the
  occasion flow works, and live refresh works over the WebSocket through kamal-proxy.
- **Follow-up in the old repo:** a Netlify `_redirects` rule sending warikan-jp.netlify.app
  to warikan.lrod.dev (0017).

## Implementation steps
1. Receipt: route, controller, view, print controller, copy, request spec, phone and print
   check.
2. Purge job and its specs.
3. README.
4. Deploy (needs Luis's server first).
5. Update `ARCHITECTURE.md`.
