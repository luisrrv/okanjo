# Spec: core flow (session 2)

- Status: Implemented (2026-11-02)
- ADRs: 0005, 0006, 0015, 0016, 0017, 0018
- Depends on: [domain model](domain-model.md)

## Goal
The whole flow works end to end in the browser: create an occasion → add members → add,
edit and delete expenses → see each person's share. Built with plain Rails forms and
redirects, with Japanese copy from locale files.

## Out of scope
- Balances, settlement and the live Turbo Stream update (session 3).
- The printable receipt, the purge job and the deploy (session 4).
- A friendly page for a deleted occasion. An unknown or purged token shows Rails' standard
  404 page for now.
- English copy (0018).

## Routes

```ruby
root "groups#new"

resources :groups, only: %i[create show], param: :token do
  resources :members, only: %i[create destroy]
  resource :identity, only: %i[create destroy]
  resources :expenses, only: %i[new create edit update destroy]
end
```

| Method | Path | Action |
|---|---|---|
| GET | `/` | start page: create an occasion, plus this browser's recent occasions |
| POST | `/groups` | create an occasion and its first member (you) |
| GET | `/groups/:token` | the occasion page |
| POST | `/groups/:token/members` | add a member |
| DELETE | `/groups/:token/members/:id` | remove a member (only with no expenses) |
| POST | `/groups/:token/identity` | "I'm this member": stored in the signed cookie |
| DELETE | `/groups/:token/identity` | "that's not me": clear it |
| GET | `/groups/:token/expenses/new` | expense form |
| POST | `/groups/:token/expenses` | create an expense |
| GET, PATCH, DELETE | `/groups/:token/expenses/:id(/edit)` | edit, update, delete |

**Always nested, never shallow.** Ids count up, so `/expenses/42` would let anyone edit
another occasion's expenses by guessing. Every controller loads the group by token
(`Group.find_by!(token: params[:group_token])`), and every member or expense through it
(`@group.expenses.find(params[:id])`). A record from another occasion isn't found, which
returns a 404.

## Identity (0006)

- **Cookie:** `cookies.signed[:members]`, a hash of `{ group token => member id }`. It
  expires after 1 year, renewed on every write, and keeps at most the 50 most recent
  occasions so it stays well under the 4 KB cookie limit.
- **A `CurrentMember` controller concern** provides `current_member`: the member for this
  occasion, or `nil` if the cookie has none or names a member who no longer exists.
- **Creating an occasion** sets the cookie to its first member, so the creator is known
  from the start.
- **"Who are you?" banner:** shown on the occasion page when `current_member` is `nil`.
  It has a button per member (POST identity) and "I'm not on the list", which adds you as
  a member and sets the cookie. It can be ignored, and the page works without it.
- **What it's used for:** only defaulting the payer on the expense form, and showing a
  small "you" marker in the member list. It isn't security, and the UI shouldn't make it
  look like a login.
- **Recent occasions on the start page:** the cookie's tokens, newest first. Tokens whose
  group no longer exists are dropped from the cookie.

## Pages

### Start page (`groups#new`)
- Form fields: occasion name (optional), your name (required). It creates the group and
  its first member in one save, using `accepts_nested_attributes_for :members`.
- Below the form: this browser's recent occasions (name or date, member count).

### Occasion page (`groups#show`)
- The name, or the creation date when there's no name.
- The deletion notice: "deleted on {date} if nothing changes" (`updated_at + 30 days`,
  0016).
- The share link: the occasion URL in a read-only field.
- The "who are you?" banner, when needed.
- **Members:** the list, with a "you" marker and a remove button for members with no
  expenses. A one-field inline form adds a member.
- **Expenses:** newest first. Each shows description, amount, payer, "1人 {share}円 × {n}
  people", the odd yen when there is any, and "{payer} paid · not sharing" when the payer
  is left out of the split. Each has edit and delete. There's an "add expense" button.
- With no expenses yet: an empty state pointing to "add expense".

### Expense form (`expenses#new` / `#edit`)
- **Description:** pre-filled お会計 {N} on new, with N = the expense count + 1 (spec
  D2).
- **Amount:** a number field, whole yen.
- **Payer:** a select of members, defaulting to `current_member`, else no selection.
- **In the split:** `collection_check_boxes :member_ids`, all ticked on new.
- **The ADR 0015 confirmation:** a Stimulus `payer-split` controller. When the payer ends
  up left out of the split, by either route, it calls the browser's `confirm()` with the
  effect in yen. Cancel puts the payer back in the split. The amounts are a browser-side
  preview; the server still computes shares when the page is read.
- Strong params: `params.expect(expense: [ :description, :amount, :payer_id, member_ids: [] ])`.
  A payer or member from another occasion is rejected by the model validations.

## Controller conventions
- **Successful create, update or delete:** redirect to the occasion page with a flash
  notice.
- **Failed validation:** re-render the form with `status: :unprocessable_content` (422).
  Turbo requires a 4xx/5xx status to show a re-rendered form.
- **Member removal refused** (`restrict_with_error`): redirect back with the error as a
  flash alert.
- **`rate_limit`** (0017, built into Rails 8): occasions 10 per minute per IP; members and
  expenses 30 per minute per IP. Rails returns 429 Too Many Requests above that.

## Copy (ja.yml)

Glosses are in English. Wording checked against how established Japanese split-the-bill
apps phrase things (立て替え, 支払者, 対象メンバー). A native speaker should still review it
before launch, especially the confirmation sentence.

| Key | Japanese | English gloss |
|---|---|---|
| `groups.new.title` | 割り勘をはじめる | Start splitting the bill |
| `groups.new.name_label` | イベント名（任意） | Event name (optional) |
| `groups.new.name_placeholder` | 例：忘年会、箱根旅行 | e.g. year-end party, Hakone trip |
| `groups.new.your_name_label` | あなたの名前 | Your name |
| `groups.new.submit` | 作成する | Create |
| `groups.new.recent` | 最近開いたイベント | Events you opened recently |
| `groups.show.deletion_notice` | 変更がない場合、%{date}に削除されます | Will be deleted on %{date} if nothing changes |
| `groups.show.share_link` | このリンクを共有してください | Share this link |
| `identities.banner.title` | あなたの名前を選んでください | Please choose your name |
| `identities.banner.not_listed` | リストにない場合は追加 | Not on the list? Add yourself |
| `members.form.submit` | 追加 | Add |
| `expenses.new.title` | 支払いを追加 | Add a payment |
| `expenses.form.default_description` | お会計 %{number} | Bill %{number} (spec D2) |
| `expenses.form.payer` | 支払った人 | Who paid |
| `expenses.form.split` | 割り勘するメンバー | Members splitting it |
| `expenses.form.confirm_payer_out` | %{payer}さんは割り勘に含まれません。%{others}で%{amount}を割り勘し、1人%{share}になります。よろしいですか？ | %{payer} isn't included in the split. %{others} split %{amount}, %{share} each. OK? |
| `expenses.expense.share` | 1人 %{share} × %{count}人 | %{share} each × %{count} people |
| `expenses.expense.odd_yen` | 端数 %{amount}（%{payer}さん） | %{amount} remainder (kept by %{payer}) |
| `expenses.expense.payer_not_sharing` | 支払い：%{payer}さん（割り勘の対象外） | Paid by %{payer} (not part of the split) |
| `flash.created` / `updated` / `destroyed` | 追加しました / 更新しました / 削除しました | Added / Updated / Deleted |

Amounts are shown as 8,000円 (`number_to_currency` with rails-i18n's Japanese format), which
reads more naturally in Japanese UI than ¥8,000.

Model and attribute names for error messages: Group = イベント, Member = メンバー,
Expense = 支払い, plus 名前, 内容 (description), 金額 (amount) and 支払った人 (payer).
"お会計" only appears as the default expense label (お会計 1, "bill 1").

- In `confirm_payer_out`, `%{others}` puts さん after each name ("Akiさん、Benさん、Chieさん"),
  so the Stimulus controller joins the names that way.
- The odd yen is called 端数 ("remainder") in the UI, the usual word in Japanese splitting
  talk (e.g. 端数は幹事が負担, "the organiser covers the remainder"). ADRs keep "odd yen".

## Edge cases
| Case | Expected |
|---|---|
| Unknown or purged token | 404 |
| An expense id from another occasion in the URL | 404 |
| Crafted `payer_id` or `member_ids` from another occasion | 422, form re-rendered with an error |
| Create with your name blank | 422, error shown, nothing created |
| Duplicate member name (Yuki / yuki) | 422 on the occasion page, error shown |
| Remove a member who paid or is in a split | refused, alert shown, member kept |
| Cookie names a member who was removed | treated as unknown; banner shown |
| Cookie names a group that was purged | dropped from recent occasions |
| Expense form with no members ticked | 422, error shown |
| Payer left out of the split, JavaScript off | saved without confirmation (0015) |
| More than 10 occasions per minute from one IP | 429 |

## Verification
1. **Request specs** (`spec/requests/`), one file per controller, covering the edge-case
   table: 404s for other occasions' records, 422s with Japanese errors, redirects and
   flashes, cookie set on create and identity, rate limits (with a memory cache store in
   that spec, since the test cache is a null store).
2. **One system spec** (headless Chrome), covering the whole flow:
   - create an occasion;
   - add two members;
   - add an expense, leave the payer out of the split and accept the confirmation;
   - see "1人 2,667円 × 3人" (2,667 yen each, 3 people) and the "not sharing" label.
3. `config.i18n.raise_on_missing_translations = true` in the test environment, so a
   missing key fails a spec.
4. `bundle exec rspec`, `bin/rubocop`, `bin/brakeman`.
5. A manual pass on a phone-sized viewport in the browser pane.

## Implementation steps
1. `rails-i18n`, the locale config, `ja.yml` model and attribute names, the layout
   (`lang="ja"`, a mobile-first Tailwind shell, flash messages).
2. Start page and group creation (nested first member, cookie, rate limit).
3. Occasion page, members (add or remove) and identity (banner, cookie, `CurrentMember`).
4. Expense form, create, edit and delete, and the `payer-split` Stimulus controller.
5. The system spec and the phone-viewport pass.

## Rails concepts this session covers
`resources` with `param:` and nesting, `params.expect`, `accepts_nested_attributes_for`,
signed cookies, controller concerns, `rate_limit`, form helpers
(`collection_check_boxes`), 422 and Turbo, Stimulus, I18n lazy lookup (`t(".title")`).
