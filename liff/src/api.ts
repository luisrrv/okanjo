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

async function request(method: Method, path: string, body?: Json, token = storedToken()): Promise<unknown> {
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (body) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (response.status === 204) return null;
  const json: unknown = await response.json().catch(() => null);
  if (response.ok) return json;

  const problem = isObject(json) ? json : {};
  throw new ApiError(
    response.status,
    typeof problem.code === 'string' ? problem.code : 'unknown',
    typeof problem.detail === 'string' ? problem.detail : '',
    parseFieldErrors(problem.errors),
  );
}

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
