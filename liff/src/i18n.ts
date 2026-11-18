/**
 * Tiny i18n module — no library, just a typed dictionary and a t() helper.
 *
 * Why no library: 15 strings of UI copy don't earn the bundle weight or runtime
 * complexity of i18next. A frozen dictionary + closure over current language is enough.
 *
 * Language detection is three-tier:
 *   1. localStorage — respects the user's previous explicit choice
 *   2. platform signal — liff.getLanguage() in prod, navigator.language in dev
 *   3. default — 'ja' (JP-first project, JP-first default)
 */

export type Lang = 'ja' | 'en';

const STORAGE_KEY = 'warikan-lang';

const dict = {
  ja: {
    appTitle: '割り勘',
    totalLabel: '合計金額',
    peopleLabel: '人数',
    perPersonLabel: '一人あたり',
    yen: '円',
    people: '人',
    shareButton: 'チャットに送る',
    placeholderTotal: '例: 4500',
    placeholderPeople: '例: 3',
    shareCardHeader: '割り勘',
    shareCardOpen: 'Warikanを開く',
  },
  en: {
    appTitle: 'Warikan',
    totalLabel: 'Total',
    peopleLabel: 'People',
    perPersonLabel: 'Per person',
    yen: '¥',
    people: 'people',
    shareButton: 'Send to chat',
    placeholderTotal: 'e.g. 4500',
    placeholderPeople: 'e.g. 3',
    shareCardHeader: 'Bill split',
    shareCardOpen: 'Open Warikan',
  },
} as const;

export type StringKey = keyof typeof dict.ja;

let currentLang: Lang = 'ja';
const listeners = new Set<(lang: Lang) => void>();

/**
 * Detects initial language. Pass an optional platform-signal getter
 * (e.g. () => liff.getLanguage()) so this module stays LIFF-agnostic.
 */
export function detectLang(platformSignal?: () => string | undefined): Lang {
  const stored = safeRead(STORAGE_KEY);
  if (stored === 'ja' || stored === 'en') return stored;

  const platform = platformSignal?.() ?? (typeof navigator !== 'undefined' ? navigator.language : '');
  if (platform?.toLowerCase().startsWith('ja')) return 'ja';
  if (platform?.toLowerCase().startsWith('en')) return 'en';

  return 'ja';
}

export function getLang(): Lang {
  return currentLang;
}

export function setLang(lang: Lang): void {
  if (lang === currentLang) return;
  currentLang = lang;
  safeWrite(STORAGE_KEY, lang);
  listeners.forEach((fn) => fn(lang));
}

/** Subscribe to language changes. Returns an unsubscribe function. */
export function onLangChange(fn: (lang: Lang) => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

/**
 * Translate a key. Strict typing means typos are compile errors.
 */
export function t(key: StringKey): string {
  return dict[currentLang][key];
}

/**
 * Translate using a specific language explicitly — used by the share message
 * so the FlexMessage reflects the sender's language choice, not the t() global.
 */
export function tIn(lang: Lang, key: StringKey): string {
  return dict[lang][key];
}

// localStorage can throw (private mode, disabled storage). Don't crash the app over it.
function safeRead(key: string): string | null {
  try {
    return typeof localStorage !== 'undefined' ? localStorage.getItem(key) : null;
  } catch {
    return null;
  }
}

function safeWrite(key: string, value: string): void {
  try {
    if (typeof localStorage !== 'undefined') localStorage.setItem(key, value);
  } catch {
    /* ignore */
  }
}