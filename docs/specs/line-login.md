# Spec: LINE Login and the LIFF app on the API (slice 2c-2)

- Status: Draft (2026-11-18)
- ADRs: 0008, 0018, 0021, 0022, 0023, 0024

## Goal
Inside LINE, the LIFF app at `/liff` signs you in with LINE and works with real occasions
through the API: your occasions, an occasion with its settlement, adding an expense or a member,
claiming your member, creating an occasion, and sharing it to a chat. An email account can link
LINE, so both sign-ins reach the same `User` (0021's 2c requirement). Signed out, the app is the
calculator it has always been, now with v2's ¥1 rounding and in Japanese only (0024, D1 and D7).

## Out of scope
- LINE Login on the website (the web OAuth flow). LINE-only accounts use the LIFF app; the
  website stays email-only for sign-in.
- Editing or deleting expenses and removing members in LIFF: the app links to the website for
  those (0024, D2).
- Push updates in LIFF: the app re-reads with `If-None-Match` when it regains focus and after
  each write (0023).
- English, and a per-occasion rounding unit (0024: a possible follow-up slice).
- Purging users or expired sessions (0022, 0023 follow-ups).

## Data model
One migration:
- `users.line_user_id`: string, nullable, unique index.
- `users.email_address` and `users.password_digest`: nullable. The unique index on
  `email_address` stays (SQLite allows many NULLs).
- A check constraint: `line_user_id IS NOT NULL OR (email_address IS NOT NULL AND
  password_digest IS NOT NULL)`. Every user can sign in some way.

`User`:
- `has_secure_password validations: false`, with the validations it no longer adds written out:
  a password is required when there's an email and no digest yet, `password_confirmation`
  must match when given, and the 72-byte cap. Email sign-up behaves exactly as in 2a; the 2a specs
  must pass unchanged.
- `validates :email_address` presence and format only when there's no `line_user_id`, or when
  it's given.
- No uniqueness validation on `line_user_id`: it comes from LINE, never a form, so its unique
  index is the guard. A validation would turn `create_or_find_by!`'s race into a `RecordInvalid`.
- `#merge_line_account!(line_user)`: in one transaction, move each of `line_user`'s claimed
  members to `self`, except in an occasion where `self` already holds a member (that one is
  released); destroy `line_user` (its sessions go with it); then set `self.line_user_id`. Claims
  are the only data a user owns (0024, D5). Destroying first frees the unique `line_user_id`.
- `#can_unlink_line?`: true when the user has an email and a password.

## Verifying LINE's ID token (0024, D3)
`LineIdToken.verify(id_token)` in `app/models/line_id_token.rb`, plain Ruby:
- `Net::HTTP.start` (`post_form` can't set timeouts) and a form `POST` to
  `https://api.line.me/oauth2/v2.1/verify` with `id_token` and `client_id` =
  `Rails.configuration.x.line.channel_id`, with 3-second open and 5-second read timeouts.
- `200`: returns the `sub` claim (the LINE user ID). LINE has checked the signature, expiry and
  audience.
- `400`: raises `LineIdToken::Invalid`.
- A timeout, a connection error or any other status: raises `LineIdToken::Unavailable`.
- `LINE_CHANNEL_ID` is plain configuration (`env.clear` in `config/deploy.yml`), read in
  `config/application.rb` into `config.x.line.channel_id`. It's checked when a LINE sign-in needs
  it, not at boot: the Docker build precompiles assets in production mode without it.
- Specs stub `Net::HTTP.start` (no WebMock: a gem would need an ADR). Request specs stub
  `LineIdToken.verify`.

## API changes
| Method and path | Purpose | Success |
|---|---|---|
| `POST /api/v1/session/line` | sign in with LINE; with `email_address` and `password`, also link that email account | `201`, the same shape as `POST /session` |
| `DELETE /api/v1/me/line` | unlink LINE from your account | `204` |
| `GET /api/v1/me` | adds `line_linked`; `email_address` is `null` for a LINE-only account | `200` |

**`POST /api/v1/session/line`**, body `{"id_token": "..."}`, optionally with `email_address`
and `password`. Rate-limited like `POST /session` (10 per 3 minutes per IP).
- **Without email:** verify the token. A user with that `line_user_id` gets a new session;
  otherwise a LINE-only user is created first.
- **With email and password:** verify the token, then authenticate the email account
  (`User.authenticate_by`).
  - That account already has this LINE ID: a new session, nothing else.
  - It has a *different* LINE ID: `409 email_account_linked_elsewhere`.
  - Otherwise: if a LINE-only user holds this LINE ID, `merge_line_account!` it; then set the
    LINE ID on the email account. If the LINE ID is held by *another email account*:
    `409 line_linked_elsewhere`.
  - The session returned is the email account's. The LINE-only user's tokens stop working with
    its sessions.
- Wrong email or password: `401 invalid_credentials`, and nothing is linked.

**`DELETE /api/v1/me/line`:** `204` and `line_user_id` set to `NULL` when
`can_unlink_line?`; otherwise `409 cannot_unlink`. `404 not_found` if LINE isn't linked.

**New problem codes**

| Code | Status | When |
|---|---|---|
| `invalid_line_token` | 401 | LINE rejected the ID token (expired, wrong channel, forged) |
| `line_unavailable` | 503 | LINE's verify endpoint timed out or failed; with `Retry-After: 30` |
| `email_account_linked_elsewhere` | 409 | the email account is linked to a different LINE account |
| `line_linked_elsewhere` | 409 | this LINE account is linked to a different email account |
| `cannot_unlink` | 409 | unlinking would leave the account with no way to sign in |

`docs/api/openapi.yaml` gets the two endpoints, the codes and the `/me` change.

## The website
- The header and anything showing `email_address` handle `nil`. A LINE-only user can't sign in
  on the website (no web LINE Login), so this only matters if one ever has a website session; it
  can't, but the views don't assume.
- Password reset finds users by email. With the address missing, `find_by(email_address: nil)`
  would find a LINE-only account, so it now looks only when an address is given.
- No other change to the core.

## The LIFF app (`liff/`)
Vanilla TypeScript, as v1 is: no framework.
- **Japanese only:** `i18n.ts` loses English and the toggle; the strings stay in one place.
- **¥1 rounding:** `calc.ts` rounds each share up to the yen and reports the payer's odd yen,
  matching `Expense#share_amount` (0008). The calculator's result for the same inputs changes
  (¥4,501 ÷ 3: ¥1,600 before, ¥1,501 now).
- **API client (`api.ts`):** `fetch` to the same origin's `/api/v1`, with the bearer token. It
  narrows every response from `unknown` with small type guards for the shapes it uses; problem
  responses become a typed error with `code` and `detail`. No validation library (a new
  dependency would need deciding).
- **Signing in (`auth.ts`):**
  - The calculator offers 「LINEでログイン」. In LINE, `liff.isLoggedIn()` is already true.
    Outside LINE, `liff.login()` redirects to LINE.
  - `liff.getIDToken()` is exchanged at `POST /session/line`. The API token is kept in
    `localStorage` and reused until a `401`; then the app exchanges a fresh ID token once, and
    asks the user to sign in again if that fails (`invalid_line_token`).
  - Sign-out calls `DELETE /session`, clears the token and `liff.logout()`.
  - Linking: a 「メールアカウントと連携」 form (email and password) calls
    `POST /session/line` with them and switches to the returned token.
- **Screens** (one page, views switched in code):
  1. **Calculator**, signed out or chosen from the menu: as v1, with ¥1 rounding.
  2. **My occasions:** `GET /me/occasions`, newest first, and 「新しい割り勘」.
  3. **New occasion:** a name (optional) and your name, prefilled from `liff.getProfile()`
     (`profile` scope). `POST /occasions`.
  4. **Occasion:** members (with 自分 for yours), expenses newest first with each share, and the
     settlement from `GET /occasions/:token`. Re-read with `If-None-Match` on focus and after
     writes. Buttons: add an expense, add a member, 「これは私」 to claim, share to chat, and
     「ウェブで編集」 linking to the website's occasion page for editing and deleting.
  5. **Add expense:** description, amount, payer (you by default), who's in the split (everyone by
     default). Validation errors show under their fields from the problem's `errors`.
- **Deep links:** `?occasion=<token>` opens that occasion after sign-in. The share card for an
  occasion links to `https://liff.line.me/<LIFF ID>?occasion=<token>`. v1's
  `?total=&people=` links still open the calculator; it now also fills those two fields in
  (2c-1 found it never did).
- **Tests:** `tsc` in the existing build. The client gets no test runner in this slice; the
  money it shows comes from the server, which is tested. A runner (Vitest) is a small follow-up
  if the client grows.

## Luis's console tasks
1. Give the channel ID of the LINE Login channel that owns the LIFF app (`LINE_CHANNEL_ID`).
2. On the LIFF app, enable the `openid` and `profile` scopes. `shareTargetPicker` stays on.
3. After deploying, check the flows below in LINE on a phone.

## Edge cases
- **First LINE sign-in:** a LINE-only account. Its occasions are the ones it claims or creates.
- **The same person signs in with LINE, then links their email account:** the LINE-only account's
  claims move to the email account, and it's deleted. In an occasion where both held a member,
  the email account's claim stays and the other member is released (still in the occasion,
  unclaimed).
- **Linking twice, or from two phones:** the second link finds the LINE ID already on the email
  account and just signs in.
- **Unlinking, then signing in with LINE again:** creates a new LINE-only account; nothing from
  the email account carries over. Linking again merges it back.
- **LINE is down:** `503 line_unavailable`. Email sign-in and existing tokens keep working; the
  app shows 「LINEに接続できません。しばらくしてからもう一度お試しください」.
- **An expired ID token from LIFF's cache:** `401 invalid_line_token`; the app calls
  `liff.login()` once to refresh it.
- **A deleted user's token** (the LINE-only side of a merge): `401`, because its sessions are
  gone. The app is mid-link at that moment and switches to the returned token.
- **A shared occasion link opened by someone who isn't a member:** they see it (the token is the
  access control, 0005) and can add themselves or claim a member.
- **The occasion was purged:** `404`; the app goes back to my occasions with a message.

## Copy (LIFF app and new API messages)
Japanese, with English glosses; a native speaker should check them.

| Where | Japanese | English gloss |
|---|---|---|
| sign in | LINEでログイン | Log in with LINE |
| my occasions | 自分の割り勘 | My occasions |
| new occasion | 新しい割り勘 | New occasion |
| your name | あなたの名前 | Your name |
| claim | これは私 | This is me |
| yours | 自分 | Me |
| edit on web | ウェブで編集 | Edit on the web |
| link email | メールアカウントと連携 | Link your email account |
| linked | 連携しました | Linked |
| sign out | ログアウト | Log out |
| `api.errors.invalid_line_token` | LINEのログイン情報を確認できませんでした。もう一度ログインしてください | Couldn't verify your LINE login. Please log in again |
| `api.errors.line_unavailable` | LINEに接続できません。しばらくしてからもう一度お試しください | Can't reach LINE. Please try again in a little while |
| `api.errors.email_account_linked_elsewhere` | このメールアカウントは別のLINEアカウントと連携済みです | This email account is linked to a different LINE account |
| `api.errors.line_linked_elsewhere` | このLINEアカウントは別のメールアカウントと連携済みです | This LINE account is linked to a different email account |
| `api.errors.cannot_unlink` | ログイン方法がなくなるため、連携を解除できません | You can't unlink: you'd have no way to log in |

## Steps
1. **Accounts:** the migration, `User` changes, `merge_line_account!`, `LineIdToken`, the
   config, `POST /session/line`, `DELETE /me/line`, `/me`; request and model specs, including all
   2a specs unchanged.
2. **The client's foundation:** Japanese only, ¥1 rounding, prefill from `total`/`people`, the
   API client, sign-in and sign-out, my occasions.
3. **Occasion screens:** the occasion, add an expense or member, claim, new occasion, share,
   deep links, linking an email account.
4. **Release:** OpenAPI and docs, deploy with `LINE_CHANNEL_ID`, then Luis checks in LINE.

## Verification
1. `bundle exec rspec`, `bin/rubocop`, `bin/brakeman` after each step; `pnpm build` in `liff/`.
2. Model specs for the merge (claims moved, the shared-occasion conflict, the LINE-only user
   gone) and the check constraint (a user with no way to sign in can't be saved, even with
   `update_column`).
3. Request specs for every row of the linking rules and every new problem code.
4. The local calculator: ¥4,501 ÷ 3 shows ¥1,501 and ¥2 odd yen.
5. **In LINE, after deploy:** first sign-in creates an account; create an occasion with your
   LINE name; add an expense and a member; share the card and open it from the chat; on the
   website, signed in with email, link LINE from LIFF and see the LIFF-created occasion under
   自分の割り勘; unlink is refused for a LINE-only account and allowed for the email account.
