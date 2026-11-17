# Spec: the JSON API, v1 (slice 2b)

- Status: Draft (2026-11-17)
- ADRs: 0005, 0006, 0008, 0013, 0021, 0022, 0023

## Goal
A client outside the website can do everything the website does with an occasion, except
print the receipt: sign in with an email account, create and read occasions, add and remove
members, claim its member, and add, edit and delete expenses. The API is built as if its client
were external (0021): bearer tokens, explicit shapes, problem details, correct status codes.
The LIFF client in 2c is its first real client; `curl` is the first one in 2b.

## Out of scope
- LINE Login and the LINE ID token exchange (2c).
- Anonymous API access: the website stays the anonymous path (0023, D1).
- Sign-up, password reset and account changes through the API: the website does these.
- Live updates for API clients: they poll with `If-None-Match` (0023).
- The receipt, CORS, pagination, `Idempotency-Key`, per-token scopes.
- Purging expired API sessions (a follow-up, 0023).

## Data model
No migration. An API sign-in creates a `Session` row like the website's. The token is
`session.signed_id(purpose: :api, expires_in: 30.days)`, and a request finds its session with
`Session.find_signed(token, purpose: :api)`. A token that's forged, expired, for another purpose,
or whose session was destroyed finds nothing.

## Structure
- `app/controllers/api/v1/base_controller.rb`: `Api::V1::BaseController < ActionController::API`.
  No cookies, no CSRF protection, no `allow_browser`. It includes
  `ActionController::HttpAuthentication::Token::ControllerMethods`, authenticates every action
  with `authenticate_with_http_token`, sets `Current.session`, and has the `rescue_from` handlers
  that render problem details.
- `Api::V1::OccasionScoped`: like `GroupScoped`, loads `@group` from `params[:occasion_token]`.
  Members and expenses are always found through `@group`, so an id from another occasion is a 404.
- Controllers, all under `Api::V1`: `SessionsController`, `MeController`,
  `Me::OccasionsController` (`namespace :me`), `OccasionsController`, `MembersController`,
  `ClaimsController`, `ExpensesController`.
- Views: jbuilder under `app/views/api/v1/`, with partials for an occasion, member, expense and
  problem. Every response shape is written there on purpose, never `render json: model`.
- The core's controllers, views and routes don't change.

## Authentication
- **Header:** `Authorization: Bearer <token>` (RFC 6750). Rails' token parser also accepts
  `Token token="..."`; that's harmless, but the docs only describe `Bearer`.
- **Missing or invalid token:** `401` with `WWW-Authenticate: Bearer realm="warikan"`, and
  `error="invalid_token"` when a token was sent but didn't verify (RFC 6750 §3). Body: the
  `unauthorized` problem.
- **`Current.user`** comes from the session, as on the website. Nothing reads cookies.

## Routes
All under `/api/v1`, JSON only (`defaults: { format: :json }`).

| Method and path | Action | Success |
|---|---|---|
| `POST /session` | sign in with `email_address` and `password` | `201`, token |
| `DELETE /session` | destroy the current session (cancels the token) | `204` |
| `GET /me` | the signed-in user | `200` |
| `GET /me/occasions` | your occasions (by claimed member), most recently changed first | `200` |
| `POST /occasions` | create an occasion with its first member, claimed by you | `201`, `Location` |
| `GET /occasions/:token` | the aggregate occasion, with ETag | `200` or `304` |
| `POST /occasions/:token/members` | add a member; `"claim": true` also claims it | `201`, `Location` |
| `DELETE /occasions/:token/members/:id` | remove a member with no expenses or splits | `204` |
| `PUT /occasions/:token/members/:id/claim` | claim a member for your account | `200` |
| `DELETE /occasions/:token/members/:id/claim` | release your claim | `204` |
| `POST /occasions/:token/expenses` | add an expense | `201`, `Location` |
| `PATCH /occasions/:token/expenses/:id` | edit an expense | `200` |
| `DELETE /occasions/:token/expenses/:id` | delete an expense | `204` |

`Location` points at the occasion for members and expenses, since neither has its own `GET`.
Every successful write returns the resource it changed; the client re-reads the occasion (a
`304` if nothing else changed) when it needs the totals.

## Requests
Flat JSON bodies. `wrap_parameters` is on for JSON (Rails' default), so
`{"amount": 3000}` reaches the expenses controller as `params[:expense][:amount]`, and the
controllers keep using `params.expect`.

- `POST /session`: `{"email_address": "...", "password": "..."}`
- `POST /occasions`: `{"name": "飲み会", "member_name": "Luis"}`. `name` is optional, as on the
  website; `member_name` is required.
- `POST /members`: `{"name": "Aki", "claim": true}`
- `POST /expenses` and `PATCH /expenses/:id`:
  `{"description": "1次会", "amount": 20000, "payer_id": 1, "member_ids": [1, 2, 3]}`.
  `PATCH` accepts any subset. `amount` is an integer number of yen. A decimal is a `422`, never
  rounded; a whole number sent as a string (`"3000"`) is accepted as that exact integer, as Rails
  casts it.

## Responses
Field names are the API's, not the schema's: `occasion` (not group), `token`, `payer_id`,
`member_ids`. Amounts are integers in yen. Times are ISO 8601 with the offset. Dates are
`YYYY-MM-DD` in Japan time.

**`POST /session` → 201**
```json
{ "token": "eyJfcmFpbHMi...", "expires_at": "2026-12-17T10:00:00+09:00",
  "user": { "id": 1, "email_address": "luis@example.com" } }
```

**`GET /me` → 200:** `{ "id": 1, "email_address": "luis@example.com" }`

**`GET /me/occasions` → 200**
```json
{ "occasions": [
  { "token": "68EMn77A7EguzuUCboeY8zw8", "name": "飲み会", "my_member_id": 1,
    "member_count": 5, "deletion_date": "2026-12-02", "updated_at": "2026-11-02T21:14:00+09:00" }
] }
```

**`GET /occasions/:token` → 200** (the aggregate, 0023 D4)
```json
{
  "token": "68EMn77A7EguzuUCboeY8zw8",
  "name": "飲み会",
  "deletion_date": "2026-12-02",
  "updated_at": "2026-11-02T21:14:00+09:00",
  "my_member_id": 1,
  "members": [
    { "id": 1, "name": "Aki", "claimed": true, "mine": true, "removable": false }
  ],
  "expenses": [
    { "id": 3, "description": "タクシー", "amount": 3000, "payer_id": 4, "member_ids": [3, 4],
      "share_amount": 1500, "collected": 3000, "odd_yen": 0,
      "created_at": "2026-11-02T21:10:00+09:00" }
  ],
  "balances": [
    { "member_id": 1, "credited": 20000, "owed": 4000, "balance": 16000 }
  ],
  "settlement": {
    "collector_id": 1,
    "transfers": [ { "from_id": 3, "to_id": 1, "amount": 8500 } ]
  }
}
```
- `members` in join order (`id`), `expenses` newest first, as on the website.
- `claimed` is whether any account holds the member; `mine` whether yours does. Other users'
  ids and emails never appear.
- `share_amount`, `collected`, `odd_yen`, the balances and the settlement come from `Expense`,
  `BalanceSheet` and `Settlement`. The client never recomputes money (0008, 0009, 0013).
- `settlement.collector_id` is `null` and `transfers` is `[]` when every balance is zero.

**Conditional GET:** `fresh_when` with an ETag from the group (whose `updated_at` moves on
every change through `touch: true`), the current user's id (`my_member_id` and `mine` differ per
user), and an API version string, so a change to the response shape invalidates old ETags.
`ActionController::API` doesn't mix in template digests, hence the version string.

**Member and expense writes** return the member or expense in the shapes above.

## Errors (RFC 9457, 0023 D5)
`Content-Type: application/problem+json`.
```json
{ "type": "https://warikan.lrod.dev/api/problems/validation_failed",
  "title": "Validation failed",
  "status": 422,
  "detail": "入力内容を確認してください",
  "code": "validation_failed",
  "errors": { "amount": [ { "code": "greater_than", "message": "金額は0より大きい値にしてください" } ] } }
```
- `title` is for developers and stays in English; `detail` is for users and is Japanese, from
  `config/locales/ja.yml`.
- `type` URIs aren't served as pages; RFC 9457 allows that. `docs/api/openapi.yaml` documents
  each one.
- `errors` keys use API field names: model errors on `members` become `member_ids`, and on
  `payer` become `payer_id`. Codes come from `errors.details`, messages from rails-i18n.

| Code | Status | When |
|---|---|---|
| `bad_request` | 400 | malformed JSON, or a missing required key (`params.expect`) |
| `unauthorized` | 401 | missing, invalid, expired or cancelled token |
| `invalid_credentials` | 401 | wrong email or password at `POST /session` |
| `not_found` | 404 | unknown occasion token, or a member or expense not in that occasion |
| `claimed_by_other` | 409 | claiming a member another account holds |
| `already_claimed_here` | 409 | claiming when your account already has a member in this occasion |
| `member_in_use` | 409 | removing a member who paid for something or is in a split |
| `validation_failed` | 422 | model validation errors, with `errors` |
| `rate_limited` | 429 | over a rate limit, with `Retry-After` in seconds |

An unexpected exception stays a plain `500`; the error isn't described to the client.

## Rate limits
Rails 8 `rate_limit`, counted per user (`by: -> { Current.user.id }`) after authentication,
except sign-in, which counts per IP. A shared `with:` handler renders `rate_limited` with
`Retry-After` set to the window; Rails' default handler only raises `TooManyRequests`, with no
header. The store is `Rails.cache`: Solid Cache in production, `:memory_store` in tests, so specs
clear it before each example.

| Endpoint | Limit |
|---|---|
| `POST /session` | 10 per 3 minutes per IP (as the website's sign-in) |
| `POST /occasions` | 10 per minute per user |
| `POST` members and expenses | 30 per minute per user |
| Everything else | 300 per minute per user |

## Edge cases
- **A token for a session destroyed by a password reset:** `401`. A reset destroys every session.
- **A token signed for another purpose** (a password-reset token, a website cookie value): `401`.
- **`DELETE /session` twice:** the second gets `401`, because its token no longer finds a
  session.
- **The occasion is purged mid-session:** `404` on its token; it drops out of `/me/occasions`.
- **Claiming a member you already hold:** `200`, unchanged. Releasing a claim you don't hold:
  `404 not_found`, so it doesn't reveal who holds it.
- **Removing your own claimed member:** allowed by the same rule as the website (no expenses or
  splits); the claim goes with it.
- **`payer_id` or `member_ids` from another occasion:** `422`, from the existing validations.
- **`member_ids` empty:** `422` (`members` presence).
- **`amount` as `3000.5` or above `Expense::MAX_AMOUNT`:** `422`. As `"3000"`: accepted, exactly.
- **Two requests claim the same member at once:** the unique index decides; the loser gets
  `409 claimed_by_other` or `already_claimed_here`, never a `500` (`Member#claim_by`).
- **`If-None-Match` after another user changed the occasion:** `200` with the new ETag.
- **A website visitor and an API client edit the same occasion:** the website's viewers get the
  Turbo refresh as usual; the API client sees it on its next poll.

## Copy
Japanese `detail` messages. Glosses in English; a native speaker should check them.

| Key | Japanese | English gloss |
|---|---|---|
| `api.errors.bad_request` | リクエストの形式が正しくありません | The request is malformed |
| `api.errors.unauthorized` | ログインが必要です | You need to log in |
| `api.errors.invalid_credentials` | メールアドレスかパスワードが正しくありません | Email or password is incorrect |
| `api.errors.not_found` | 見つかりませんでした | Not found |
| `api.errors.claimed_by_other` | このメンバーは別のアカウントと連携済みです | This member is linked to another account |
| `api.errors.already_claimed_here` | アカウントはこのイベントの別のメンバーと連携済みです | Your account is already linked to another member in this occasion |
| `api.errors.member_in_use` | 支払いに関わっているメンバーは削除できません | A member involved in an expense can't be removed |
| `api.errors.validation_failed` | 入力内容を確認してください | Please check what you entered |
| `api.errors.rate_limited` | しばらくしてからもう一度お試しください | Please try again in a little while |

`claimed_by_other`, `already_claimed_here` and `rate_limited` reuse the website's wording (2a).

## Steps
1. **Foundation:** routes, `BaseController`, token authentication, problem details and the
   `rescue_from` handlers, the rate-limit handler, `POST/DELETE /session`, `GET /me`. Request
   specs for every authentication edge case.
2. **Reading:** `GET /occasions/:token` (aggregate and ETag), `GET /me/occasions`,
   `POST /occasions`. Contract specs pinning the full shapes.
3. **Writing:** members, claims, expenses, with specs for every error code in the table.
4. **Documentation and release:** `docs/api/openapi.yaml`, an API section in
   `docs/ARCHITECTURE.md`, a `curl` walkthrough in the README, then deploy.

## Verification
1. `bundle exec rspec`, `bin/rubocop`, `bin/brakeman` after each step.
2. **Contract specs:** each endpoint's response compared to its full expected shape (keys and
   types), so an added, removed or renamed field fails a spec.
3. **The website is untouched:** the existing specs pass unchanged, and `git diff` after 2b shows
   no changes to the core's controllers, views or routes outside the new `namespace :api`.
4. **In production after step 4,** with `curl`: sign in, create an occasion, add members and an
   expense, read it, repeat the read with `If-None-Match` for a `304`, check the occasion on the
   website, then `DELETE /session` and see the token rejected.
