/**
 * Local-dev shim for the LIFF SDK. Mirrors only the calls we use.
 *
 * Why this exists: LIFF apps run inside the LINE in-app webview. Outside LINE,
 * `liff.init()` fails. Rather than push every change and test inside LINE,
 * we route to this mock during dev (`import.meta.env.DEV`) and to the real
 * `@line/liff` SDK in production builds.
 *
 * Same shape as the real SDK calls — no `if (mock)` branching at the call sites.
 *
 * Signing in can't be mocked end to end: the server checks ID tokens with LINE. To try the
 * signed-in screens locally, get a token from POST /api/v1/session (an email account) and store
 * it under the `warikan-api-token` key in localStorage.
 */

type Message = unknown; // we don't validate shape here — the real SDK does

const liffMock = {
  async init(_config: { liffId: string }): Promise<void> {
    console.info('[liff-mock] init() — running outside LINE');
  },

  isInClient(): boolean {
    return true;
  },

  isLoggedIn(): boolean {
    return false;
  },

  login(_config?: { redirectUri?: string }): void {
    alert('[mock] LINE login is not available locally. See liff-mock.ts.');
  },

  logout(): void {
    console.info('[liff-mock] logout()');
  },

  getIDToken(): string | null {
    return null;
  },

  async getProfile(): Promise<{ displayName: string }> {
    return { displayName: 'ローカル太郎' };
  },

  async shareTargetPicker(messages: Message[]): Promise<{ status: 'success' }> {
    console.group('[liff-mock] shareTargetPicker');
    console.log('would send messages:', messages);
    console.groupEnd();

    const summary = JSON.stringify(messages, null, 2);
    alert(`[mock] would open LINE picker.\n\n${summary.slice(0, 400)}${summary.length > 400 ? '...' : ''}`);

    return { status: 'success' };
  },
};

// Match the real SDK's default-export shape so the dynamic import in main.ts works.
export default liffMock;
