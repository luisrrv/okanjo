# Spec: receipt, purge job, README, deploy (session 4)

- Status: Draft
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
