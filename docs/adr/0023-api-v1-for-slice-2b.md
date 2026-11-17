# 0023. The JSON API for slice 2b: bearer sessions, occasions, problem details

- Status: Accepted
- Date: 2026-11-17
- Decider: Luis

## Context
Slice 2b (0021) adds a JSON API at `/api/v1` that the LIFF client will use in 2c. 0021 already
fixed its outline: bearer tokens and never cookies, a versioned namespace with its own
controllers, explicit response shapes with jbuilder, machine-readable error codes, correct HTTP
semantics, contract tests, and no CORS.

The website's access model doesn't map onto an API directly. An occasion's link is its only
access control (0005), anyone with the link can act as any member (0006), and an account only
decides which occasions are listed for you (0022). Six decisions are left: who may call the API,
what the token is, what the resources are called, how an occasion is read, the error format and
the documentation.

## Options considered
**D1. Who can call the API:**
1. **A bearer token on every endpoint; the occasion token in the URL still grants access to
   that occasion.** The bearer token says who you are, the link says which occasion. Pros: one
   way to authenticate, rate limits per user, every write traceable to an account. Cons: the
   API needs an account.
2. **Occasion endpoints open to anyone with the link, the bearer token optional.** Mirrors the
   website. Cons: two authentication paths in every controller, and anonymous writes can only be
   limited by IP.
3. **Only occasions where you have a member.** Contradicts 0005 and 0022 and breaks invite links.

**D2. What the bearer token is:**
1. **A signed `Session` id.** Signing in through the API creates a `Session` row (the generator's
   model), and the token is `session.signed_id(purpose: :api, expires_in: 30.days)`, checked with
   `Session.find_signed(token, purpose: :api)`. Pros: no migration and no gem; nothing secret is
   stored, so a leaked database or backup holds no usable tokens; cancelling a token is
   destroying its session, so a password reset (which destroys all sessions) also signs out API
   clients; the same mechanism as the website's `cookies.signed[:session_id]`. Cons: anyone with
   `secret_key_base` can forge tokens, and rotating it signs everyone out; the expiry is fixed in
   the token; no scopes, names or recognisable prefix for secret scanning.
2. **A random token stored as a SHA-256 digest** in an `api_tokens` table, as GitHub personal
   access tokens and Stripe keys do. Pros: the standard for user-managed API keys; sliding expiry,
   scopes, `last_used_at`, a `wk_` prefix; independent of `secret_key_base`. Cons: a new model and
   hand-written token handling, and a second session concept beside `Session`.
3. **JWT.** Pros: checked without a database; the standard when the issuer and the checker are
   different systems (identity providers, federation, microservices). Cons: a gem; a token can't
   be cancelled before `exp` without refresh tokens or a denylist, which brings the database
   lookup back; known pitfalls (`alg: none`, HS/RS confusion).

**D3. Resource naming:** `/api/v1/occasions/:token`, the product's word, or
`/api/v1/groups/:token`, the table's.

**D4. Reading an occasion:**
1. **One aggregate response:** the occasion with members, expenses (with shares), balances and
   the settlement, all computed on the server, with an ETag so polling costs a 304.
2. **Separate endpoints** for balances and settlement: three requests per screen, assembled by
   the client.

**D5. Error format:** RFC 9457 problem details (`application/problem+json`) with a `code` and
per-field `errors`, or a custom `{ "error": { "code", "message" } }` shape.

**D6. Documentation:**
1. A hand-written OpenAPI 3.1 file, with request specs pinning the shapes.
2. The same file, validated in the specs by a gem (`committee` or `json_schemer`).
3. A Markdown reference only.

## Decision
- **D1: option 1.** Every endpoint except signing in needs a bearer token. Occasions are still
  reached by their token, and an account still doesn't restrict which occasions you can open.
  In 2c every LIFF user signs in through LINE; other clients use an email account. The website
  stays anonymous.
- **D2: option 1, the signed `Session` id,** sent as `Authorization: Bearer <token>`
  (RFC 6750) and valid for 30 days. The story for 2c: the app *verifies* JWTs issued by LINE and
  *issues* its own server-side tokens. JWT's advantage, checking without a database, buys nothing
  when the issuer and the checker are the same app with the same database, and it costs instant
  cancelling. If users ever manage their own keys (scopes, a token page, leak scanning), option 2
  replaces only the issuing code and one lookup; the header doesn't change.
- **D3: `occasions`.** The API uses the product's language, not the schema's. The model stays
  `Group`.
- **D4: option 1,** the aggregate `GET /api/v1/occasions/:token` with `fresh_when` for a
  conditional GET. Writes are separate endpoints for members, claims and expenses. v1 covers what
  the website does, except the printable receipt.
- **D5: RFC 9457,** with extension members `code` and `errors`. `detail` carries the Japanese
  message.
- **D6: option 1,** `docs/api/openapi.yaml` written by hand. Automatic validation waits until
  drift actually happens.
- **No new gem.** jbuilder is already in the Gemfile; token parsing uses Rails'
  `ActionController::HttpAuthentication::Token`; rate limits use Rails 8's `rate_limit`.

## Consequences
- **`secret_key_base` becomes more sensitive:** besides cookies, it now protects API tokens.
  Rotating it signs out every browser and API client at once.
- **API sessions accumulate.** Sessions aren't purged (0022), and an expired API token leaves its
  row behind. Purging sessions whose tokens have expired is a follow-up, not part of 2b.
- **Some controller logic is written twice:** creating an occasion claims its first member on
  both the website and the API. The rules live on the models (`Member#claim_by`), so the
  duplication is a few lines per action. Extract it only if it grows.
- **Live updates stay HTML-only.** API clients poll with `If-None-Match`; Turbo broadcasts (0019)
  don't reach them.
- **2c adds one sign-in route,** exchanging a LINE ID token for the same kind of session token.
  Nothing in 2b assumes email is the only way in.
- **The API's shapes are public promises.** Changing a field's meaning needs `/api/v2`; adding a
  field doesn't. The request specs and the OpenAPI file hold this, by discipline (0021).
