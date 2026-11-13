# Spec: optional accounts and "my occasions" (slice 2a)

- Status: In progress (steps 1–2 done)
- ADRs: 0006, 0016, 0021, 0022

## Goal
A user can sign up with email and password, sign in, and see their occasions on any device.
Signing in links them to their member in each occasion. Without an account, everything works
as it does today.

## Out of scope
- LINE Login, the API, and LINE-only accounts (2b, 2c).
- Email confirmation, changing email or password while signed in, and account deletion.
- Locking claimed members against anonymous use (0022: a claim is about listing, not access).
- Purging users or sessions.
- A display name on `User`.

## Data model
- **`users`** (generator): `email_address` (NOT NULL, unique), `password_digest` (NOT NULL).
  `has_many :sessions, dependent: :destroy`, `has_many :members, dependent: :nullify`.
  A password of at least 8 characters; `has_secure_password` already caps it at 72 bytes.
- **`sessions`** (generator): `user_id`, `ip_address`, `user_agent`.
- **`members.user_id`:** nullable, a foreign key with `on_delete: :nullify`, and a unique
  index on `[group_id, user_id]`. `belongs_to :user, optional: true`, plus a uniqueness
  validation scoped to `group_id` that allows nil. Built as `[user_id, group_id]`: the same
  rule, and with `user_id` first the index also serves "this user's occasions".
- **Claiming lives on `Member`:** `claim_by(user)` returns false if another user already
  holds the member or the user already has another member in this occasion, and `release_by(user)`
  only works for the user who holds it.

## Generator, and what changes after it runs
`bin/rails generate authentication`, then:
- **Login stays optional:** `allow_unauthenticated_access` on `GroupsController`,
  `MembersController`, `IdentitiesController`, `ExpensesController`, `ReceiptsController`.
  A request spec visits every core page signed out to catch a missed one.
- **Action Cable:** `ApplicationCable::Connection` sets `current_user` when there's a valid
  session cookie and accepts the connection either way.
- **`params.expect` for sign-up** (`user: [...]`, a model form). Sign-in and the reset form
  keep the generator's `params.permit(:email_address, :password)`: those are top-level scalar
  fields with no root key, and `permit` already drops anything that isn't a scalar. `expect`
  earns its place on nested hashes, where a malformed shape should be a 400 rather than a 500.
- **Japanese copy** for every generated message (`t(".…")`, see Copy), including the rate-limit
  alerts and the reset email.
- **Sign-out** (`terminate_session`) also clears the members cookie, so the next person on a
  shared device doesn't inherit who you were. Your claims are in the account.
- **Specs:** whatever `rspec:authentication` generates, rewritten to the readable-RSpec rule,
  plus request specs for the flows below.

## Routes
- `resource :session` (generator): sign in, sign out.
- `resources :passwords, param: :token` (generator): reset.
- `resource :registration, only: %i[new create]`: sign up. Rate-limited like sign-in.

## Flows
- **Sign up:** email, password, confirmation. On success: start a session, claim the
  remembered members (below), go back to where you came from or home.
- **Sign in:** on success, claim the remembered members, then redirect.
- **Claiming remembered members:** for each occasion in the members cookie with a chosen
  member, claim it if nobody holds it and the user has no member there yet. Skip anything
  else silently.
- **Creating an occasion while signed in** claims its first member.
- **"I'm this member" while signed in** claims the member. If another account holds it, the
  identity isn't set and an alert says so.
- **"Not me" (identity destroy) while signed in** releases your claim and forgets the
  cookie entry.
- **Current member when signed in:** your claimed member in this occasion, otherwise the cookie.
- **Home page:**
  - signed in: 自分の割り勘, your occasions by claimed member, most recently changed first;
    then the cookie's recent list without those;
  - signed out: unchanged.
- **Header:** ログイン when signed out; ログアウト when signed in.
- **Member banner:** a member claimed by another account shows 連携済み and has no "I'm this
  member" button for signed-in users. Signed-out visitors see the badge, and can still pick it.

## Email (0022)
**Luis sets up, in the Oracle console and at Gandi:**
1. **Email Delivery → Email Domains:** create `warikan.lrod.dev`, then add DKIM. Oracle
   gives a CNAME record.
2. **At Gandi**, on `warikan.lrod.dev`:
   - the DKIM CNAME;
   - SPF: a TXT record `v=spf1 include:<Oracle's SPF value for the region> ~all`;
   - DMARC: a TXT record on `_dmarc.warikan.lrod.dev`, `v=DMARC1; p=none`.
3. **Approved Senders:** `no-reply@warikan.lrod.dev`.
4. **SMTP credentials:** profile → SMTP credentials → Generate. Save both values in the
   keychain with the `pbpaste` method, as `okanjo-smtp-username` and `okanjo-smtp-password`.
5. **Check:** the sending limit for the account, and the SMTP endpoint for Osaka.

**Claude implements:**
- Production `smtp_settings` from the endpoint (port 587, STARTTLS) and the two credentials,
  read by `.kamal/secrets` and passed in `env.secret`.
- `default_url_options` host `warikan.lrod.dev`; the sender `割り勘 <no-reply@warikan.lrod.dev>`.
- Development keeps Rails' default: the email isn't delivered, but its full text (and the reset
  link) is in the log. A mailer preview shows the reset email.

## Edge cases
- **Signed out, anywhere in the core:** no redirects to sign-in, and live refresh still works.
- **Two tabs claim the same member at once:** the unique index decides; the loser gets the
  "linked to another account" alert, not a 500.
- **The cookie names a member the user can't claim** (held by someone else, or the user
  already has a member there): sign-in succeeds and that entry stays cookie-only.
- **A claimed member is removed from the occasion:** allowed under the existing rule (no
  expenses, no splits); the claim goes with it.
- **The occasion is purged:** its members go with it, so it disappears from 自分の割り勘.
- **Password reset for an unknown address:** the same message as for a known one (the
  generator's behaviour), so it doesn't reveal who has an account.
- **An expired or tampered reset link:** back to the reset form with an alert.
- **A reset ends all of that user's sessions** (generator behaviour).

## Copy
`config/locales/ja.yml` will be the source of truth. Glosses are in English. A native speaker
should review these before deploy.

| Key | Japanese | English gloss |
|---|---|---|
| `layouts.application.sign_in` | ログイン | Log in |
| `layouts.application.sign_out` | ログアウト | Log out |
| `sessions.new.title` | ログイン | Log in |
| `sessions.new.email` | メールアドレス | Email address |
| `sessions.new.password` | パスワード | Password |
| `sessions.new.submit` | ログイン | Log in |
| `sessions.new.forgot` | パスワードを忘れた場合 | Forgot your password? |
| `sessions.new.sign_up` | アカウントを作成 | Create an account |
| `sessions.create.invalid` | メールアドレスかパスワードが正しくありません | Email or password is incorrect |
| `rate_limited` (shared) | しばらくしてからもう一度お試しください | Please try again in a little while |
| `registrations.new.title` | アカウント作成 | Create an account |
| `registrations.new.note` | アカウントがなくても割り勘は使えます。ログインすると、どの端末からでも自分の割り勘を開けます。 | You can use warikan without an account. Logging in lets you open your occasions from any device. |
| `registrations.new.password_confirmation` | パスワード（確認） | Password (again) |
| `registrations.new.submit` | 作成する | Create |
| `registrations.new.sign_in` | アカウントをお持ちの方はログイン | Already have an account? Log in |
| `registrations.create.created` | アカウントを作成しました | Account created |
| `passwords.new.title` | パスワードの再設定 | Reset your password |
| `passwords.new.note` | 登録したメールアドレスに、再設定用のリンクを送ります。 | We'll send a reset link to your registered email address. |
| `passwords.new.submit` | 送信する | Send |
| `passwords.create.sent` | メールアドレスが登録されていれば、再設定用のリンクを送りました。 | If that email address is registered, we've sent a reset link. |
| `passwords.edit.title` | 新しいパスワード | New password |
| `passwords.edit.submit` | 変更する | Change |
| `passwords.update.updated` | パスワードを変更しました。ログインしてください。 | Password changed. Please log in. |
| (validation messages) | rails-i18n, e.g. パスワード（確認）とパスワードの入力が一致しません | Password (again) doesn't match Password |
| `passwords.invalid_token` | リンクが無効か、有効期限が切れています | The link is invalid or has expired |
| `passwords_mailer.reset.subject` | 【割り勘】パスワードの再設定 | [warikan] Reset your password |
| `passwords_mailer.reset.body` | 下のリンクからパスワードを再設定してください。リンクの有効期限は%{expires_in}です。 | Reset your password with the link below. It expires in %{expires_in}. |
| `passwords_mailer.reset.ignore` | 心当たりがない場合は、このメールを無視してください。 | If you didn't ask for this, ignore this email. |
| `groups.new.mine` | 自分の割り勘 | My occasions |
| `identities.banner.claimed` | 連携済み | Linked |
| `activerecord.errors.models.member.claimed_by_other` | このメンバーは別のアカウントと連携済みです | This member is linked to another account |
| `…member.attributes.user_id.taken` | アカウントはこのイベントの別のメンバーと連携済みです | Your account is already linked to another member in this occasion |

`%{expires_in}` comes from `distance_of_time_in_words` with rails-i18n, i.e. 15分.

## Steps
1. **Generator and sign-up:** the generator, the four changes, registration, copy, specs.
   Nothing about members yet. Not deployed.
2. **Claiming and 自分の割り勘:** the migration, `Member#claim_by` / `release_by`, the
   flows above, the banner badge, specs including a system spec for the whole path.
3. **Production email:** Luis's console and DNS steps, then the SMTP settings and secrets,
   then deploy.

## Verification
1. `bundle exec rspec`, `bin/rubocop`, `bin/brakeman`, after each step.
2. **Signed out:** the existing core flow and live-refresh system specs pass unchanged.
3. **Two browsers, one account:** create an occasion signed in on one; sign in on the other and
   see it under 自分の割り勘.
4. **In production after step 3:** request a reset for Luis's own address, receive it (check
   it's not in spam, and that DKIM passes in the message headers), reset, sign in.
5. **Live refresh signed in and signed out,** on the deployed app: the WebSocket connects
   for both.
