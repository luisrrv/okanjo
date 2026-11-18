/**
 * Signing in with LINE (ADR 0024): LIFF's ID token is traded for this app's token, which is reused
 * until a 401. Only an explicit tap starts it, so opening the calculator never creates an account.
 */

import { ApiError, forgetToken, signInWithIdToken, signOut as apiSignOut, storedToken } from './api';

export type LiffAuth = {
  isInClient(): boolean;
  isLoggedIn(): boolean;
  login(config?: { redirectUri?: string }): void;
  logout(): void;
  getIDToken(): string | null;
};

// Outside LINE, liff.login() leaves the page; this remembers to finish signing in on return.
const PENDING_KEY = 'warikan-signing-in';

export function isSignedIn(): boolean {
  return storedToken() !== null;
}

/**
 * Starts or finishes signing in. Resolves true once signed in; false when LINE's login page is
 * about to take over (outside LINE).
 */
export async function signIn(liff: LiffAuth): Promise<boolean> {
  if (!liff.isLoggedIn()) {
    sessionStorage.setItem(PENDING_KEY, '1');
    liff.login({ redirectUri: location.href });
    return false;
  }
  sessionStorage.removeItem(PENDING_KEY);

  const idToken = liff.getIDToken();
  if (!idToken) throw new ApiError(401, 'invalid_line_token', '');
  await signInWithIdToken(idToken);
  return true;
}

/** True when the page is back from LINE's login page and should finish signing in. */
export function returningFromLogin(liff: LiffAuth): boolean {
  return sessionStorage.getItem(PENDING_KEY) === '1' && liff.isLoggedIn();
}

/**
 * Runs an API call; on a 401 (the token expired or was cancelled), trades a fresh ID token once
 * and retries. A second failure reaches the caller.
 */
export async function withSession<T>(liff: LiffAuth, call: () => Promise<T>): Promise<T> {
  try {
    return await call();
  } catch (error) {
    if (!(error instanceof ApiError) || error.status !== 401) throw error;
    forgetToken();
    if (!(await signIn(liff))) throw error;
    return call();
  }
}

export async function signOut(liff: LiffAuth): Promise<void> {
  await apiSignOut().catch(() => undefined);
  if (liff.isLoggedIn() && !liff.isInClient()) liff.logout();
}
