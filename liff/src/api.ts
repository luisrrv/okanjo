/**
 * The warikan API, same origin (ADR 0023). Every response is `unknown` until a guard below has
 * checked the fields this app uses; problem responses (RFC 9457) become an ApiError.
 */

const BASE = '/api/v1';
const TOKEN_KEY = 'warikan-api-token';

// ---------- Errors ----------

export type FieldErrors = Record<string, { code: string; message: string }[]>;

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly detail: string;
  readonly fieldErrors: FieldErrors;

  constructor(status: number, code: string, detail: string, fieldErrors: FieldErrors = {}) {
    super(`${status} ${code}: ${detail}`);
    this.status = status;
    this.code = code;
    this.detail = detail;
    this.fieldErrors = fieldErrors;
  }
}

// ---------- Guards ----------

type Json = Record<string, unknown>;

function isObject(value: unknown): value is Json {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function string(value: unknown, field: string): string {
  if (typeof value !== 'string') throw new TypeError(`${field}: expected a string`);
  return value;
}

function nullableString(value: unknown, field: string): string | null {
  return value === null ? null : string(value, field);
}

function integer(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value)) throw new TypeError(`${field}: expected an integer`);
  return value;
}

function object(value: unknown, field: string): Json {
  if (!isObject(value)) throw new TypeError(`${field}: expected an object`);
  return value;
}

function array(value: unknown, field: string): unknown[] {
  if (!Array.isArray(value)) throw new TypeError(`${field}: expected an array`);
  return value;
}

function parseFieldErrors(value: unknown): FieldErrors {
  if (!isObject(value)) return {};
  const result: FieldErrors = {};
  for (const [field, errors] of Object.entries(value)) {
    if (!Array.isArray(errors)) continue;
    result[field] = errors.filter(isObject).map((error) => ({
      code: String(error.code ?? ''),
      message: String(error.message ?? ''),
    }));
  }
  return result;
}

// ---------- Shapes this app reads ----------

export type Session = { token: string; expiresAt: string };

export type OccasionSummary = {
  token: string;
  name: string | null;
  myMemberId: number;
  memberCount: number;
  deletionDate: string;
};

export type Me = { id: number; emailAddress: string | null; lineLinked: boolean };

export type Member = { id: number; name: string; claimed: boolean; mine: boolean; removable: boolean };

export type Expense = {
  id: number;
  description: string;
  amount: number;
  payerId: number;
  memberIds: number[];
  shareAmount: number;
  collected: number;
  oddYen: number;
};

export type Balance = { memberId: number; credited: number; owed: number; balance: number };

export type Transfer = { fromId: number; toId: number; amount: number };

/** Computed on the server (ADR 0008, 0013); the app only displays it. */
export type Occasion = {
  token: string;
  name: string | null;
  deletionDate: string;
  myMemberId: number | null;
  members: Member[];
  expenses: Expense[];
  balances: Balance[];
  settlement: { collectorId: number | null; transfers: Transfer[] };
};

function boolean(value: unknown, field: string): boolean {
  if (typeof value !== 'boolean') throw new TypeError(`${field}: expected a boolean`);
  return value;
}

function nullableInteger(value: unknown, field: string): number | null {
  return value === null ? null : integer(value, field);
}

function parseMe(body: unknown): Me {
  const json = object(body, 'me');
  return {
    id: integer(json.id, 'id'),
    emailAddress: nullableString(json.email_address, 'email_address'),
    lineLinked: boolean(json.line_linked, 'line_linked'),
  };
}

function parseOccasion(body: unknown): Occasion {
  const json = object(body, 'occasion');
  const settlement = object(json.settlement, 'settlement');
  return {
    token: string(json.token, 'token'),
    name: nullableString(json.name, 'name'),
    deletionDate: string(json.deletion_date, 'deletion_date'),
    myMemberId: nullableInteger(json.my_member_id, 'my_member_id'),
    members: array(json.members, 'members').map((item, i) => {
      const m = object(item, `members[${i}]`);
      return {
        id: integer(m.id, 'id'),
        name: string(m.name, 'name'),
        claimed: boolean(m.claimed, 'claimed'),
        mine: boolean(m.mine, 'mine'),
        removable: boolean(m.removable, 'removable'),
      };
    }),
    expenses: array(json.expenses, 'expenses').map((item, i) => {
      const e = object(item, `expenses[${i}]`);
      return {
        id: integer(e.id, 'id'),
        description: string(e.description, 'description'),
        amount: integer(e.amount, 'amount'),
        payerId: integer(e.payer_id, 'payer_id'),
        memberIds: array(e.member_ids, 'member_ids').map((id) => integer(id, 'member_ids[]')),
        shareAmount: integer(e.share_amount, 'share_amount'),
        collected: integer(e.collected, 'collected'),
        oddYen: integer(e.odd_yen, 'odd_yen'),
      };
    }),
    balances: array(json.balances, 'balances').map((item, i) => {
      const b = object(item, `balances[${i}]`);
      return {
        memberId: integer(b.member_id, 'member_id'),
        credited: integer(b.credited, 'credited'),
        owed: integer(b.owed, 'owed'),
        balance: integer(b.balance, 'balance'),
      };
    }),
    settlement: {
      collectorId: nullableInteger(settlement.collector_id, 'collector_id'),
      transfers: array(settlement.transfers, 'transfers').map((item, i) => {
        const tr = object(item, `transfers[${i}]`);
        return { fromId: integer(tr.from_id, 'from_id'), toId: integer(tr.to_id, 'to_id'), amount: integer(tr.amount, 'amount') };
      }),
    },
  };
}

function parseSession(body: unknown): Session {
  const json = object(body, 'session');
  return { token: string(json.token, 'token'), expiresAt: string(json.expires_at, 'expires_at') };
}

function parseOccasionSummaries(body: unknown): OccasionSummary[] {
  return array(object(body, 'body').occasions, 'occasions').map((item, i) => {
    const json = object(item, `occasions[${i}]`);
    return {
      token: string(json.token, 'token'),
      name: nullableString(json.name, 'name'),
      myMemberId: integer(json.my_member_id, 'my_member_id'),
      memberCount: integer(json.member_count, 'member_count'),
      deletionDate: string(json.deletion_date, 'deletion_date'),
    };
  });
}

// ---------- The token ----------
// Kept in localStorage and reused until a 401 (ADR 0024), so a launch doesn't create a session
// each time. localStorage can throw (private mode); the app then just signs in again.

export function storedToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

function storeToken(token: string | null): void {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* ignore: the token lives only as long as the page */
  }
}

// ---------- Requests ----------

type Method = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';

type Sent = { status: number; etag: string | null; body: unknown };

async function send(
  method: Method,
  path: string,
  { body, token = storedToken(), ifNoneMatch }: { body?: Json; token?: string | null; ifNoneMatch?: string } = {},
): Promise<Sent> {
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (body) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;
  if (ifNoneMatch) headers['If-None-Match'] = ifNoneMatch;

  const response = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
    // The ETag is ours to send; the browser's own cache must not answer for the server.
    cache: 'no-store',
  });
  const etag = response.headers.get('ETag');

  if (response.status === 204 || response.status === 304) return { status: response.status, etag, body: null };
  const json: unknown = await response.json().catch(() => null);
  if (response.ok) return { status: response.status, etag, body: json };

  const problem = isObject(json) ? json : {};
  throw new ApiError(
    response.status,
    typeof problem.code === 'string' ? problem.code : 'unknown',
    typeof problem.detail === 'string' ? problem.detail : '',
    parseFieldErrors(problem.errors),
  );
}

async function request(method: Method, path: string, body?: Json, token?: string | null): Promise<unknown> {
  return (await send(method, path, { body, token })).body;
}

const occasionPath = (token: string) => `/occasions/${encodeURIComponent(token)}`;

// ---------- Endpoints ----------

/** Trades LINE's ID token for this app's token, and keeps it. */
export async function signInWithIdToken(idToken: string): Promise<Session> {
  const session = parseSession(await request('POST', '/session/line', { id_token: idToken }, null));
  storeToken(session.token);
  return session;
}

/** Cancels the token on the server (best effort) and forgets it here. */
export async function signOut(): Promise<void> {
  try {
    await request('DELETE', '/session');
  } finally {
    storeToken(null);
  }
}

export function forgetToken(): void {
  storeToken(null);
}

export async function myOccasions(): Promise<OccasionSummary[]> {
  return parseOccasionSummaries(await request('GET', '/me/occasions'));
}

export async function me(): Promise<Me> {
  return parseMe(await request('GET', '/me'));
}

/**
 * Links an email account to this LINE account (ADR 0024): the server merges a LINE-only account
 * into it, and the returned token is the email account's.
 */
export async function linkEmailAccount(idToken: string, emailAddress: string, password: string): Promise<Session> {
  const session = parseSession(
    await request('POST', '/session/line', { id_token: idToken, email_address: emailAddress, password }, null),
  );
  storeToken(session.token);
  return session;
}

/** The whole occasion, or `null` when the ETag sent still matches (304). */
export async function getOccasion(token: string, etag?: string): Promise<{ occasion: Occasion; etag: string | null } | null> {
  const sent = await send('GET', occasionPath(token), { ifNoneMatch: etag });
  return sent.status === 304 ? null : { occasion: parseOccasion(sent.body), etag: sent.etag };
}

export async function createOccasion(name: string, memberName: string): Promise<Occasion> {
  return parseOccasion(await request('POST', '/occasions', { name: name || null, member_name: memberName }));
}

export async function addMember(occasionToken: string, name: string, claim: boolean): Promise<void> {
  await request('POST', `${occasionPath(occasionToken)}/members`, { name, claim });
}

export async function claimMember(occasionToken: string, memberId: number): Promise<void> {
  await request('PUT', `${occasionPath(occasionToken)}/members/${memberId}/claim`);
}

export type NewExpense = { description: string; amount: number; payerId: number; memberIds: number[] };

export async function addExpense(occasionToken: string, expense: NewExpense): Promise<void> {
  await request('POST', `${occasionPath(occasionToken)}/expenses`, {
    description: expense.description,
    amount: expense.amount,
    payer_id: expense.payerId,
    member_ids: expense.memberIds,
  });
}
