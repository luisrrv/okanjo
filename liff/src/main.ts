import './style.css';

// Route between mock (dev) and real SDK (prod). Same call sites either way.
const liff = import.meta.env.DEV
  ? (await import('./liff-mock')).default
  : (await import('@line/liff')).default;

// Initialize LIFF. In dev the mock no-ops; in prod this actually contacts LINE.
const LIFF_ID = import.meta.env.VITE_LIFF_ID;
if (!import.meta.env.DEV && !LIFF_ID) {
  throw new Error('VITE_LIFF_ID is required in production builds');
}
await liff.init({ liffId: LIFF_ID ?? 'dev-no-id' });

import { t, type StringKey } from './i18n';
import { splitBill, type SplitResult } from './calc';
import { formatDate, formatYen, parseNumeric } from './format';
import { shareResult } from './share';
import { ApiError, myOccasions } from './api';
import { isSignedIn, returningFromLogin, signIn, signOut, withSession } from './auth';

// ---------- DOM lookup ----------

const $ = <T extends HTMLElement>(sel: string): T => {
  const el = document.querySelector<T>(sel);
  if (!el) throw new Error(`Missing element: ${sel}`);
  return el;
};

const totalInput = $<HTMLInputElement>('#total');
const peopleInput = $<HTMLInputElement>('#people');
const resultEl = $<HTMLSpanElement>('#result');
const surplusEl = $<HTMLParagraphElement>('#surplus');
const shareBtn = $<HTMLButtonElement>('#share');
const messageEl = $<HTMLParagraphElement>('#message');
const calculatorView = $<HTMLElement>('#calculator');
const occasionsView = $<HTMLElement>('#occasions');
const occasionList = $<HTMLUListElement>('#occasion-list');
const occasionsStatus = $<HTMLParagraphElement>('#occasions-status');
const navCalculator = $<HTMLButtonElement>('#nav-calculator');
const navOccasions = $<HTMLButtonElement>('#nav-occasions');
const signInBtn = $<HTMLButtonElement>('#sign-in');
const signOutBtn = $<HTMLButtonElement>('#sign-out');

// ---------- Copy ----------

document.querySelectorAll<HTMLElement>('[data-i18n]').forEach((el) => {
  const key = el.dataset.i18n as StringKey | undefined;
  if (key) el.textContent = t(key);
});
totalInput.placeholder = t('placeholderTotal');
peopleInput.placeholder = t('placeholderPeople');

function syncSuffixPadding(): void {
  document.querySelectorAll<HTMLElement>('.input-wrap').forEach((wrap) => {
    const suffix = wrap.querySelector<HTMLElement>('.suffix');
    if (!suffix) return;
    // suffix sits 14px from the right edge; pad input by suffix width + that gap + breathing room
    const pad = Math.ceil(suffix.getBoundingClientRect().width) + 14 + 8;
    wrap.style.setProperty('--suffix-pad', `${pad}px`);
  });
}
window.addEventListener('resize', syncSuffixPadding);
syncSuffixPadding();

// ---------- Messages ----------

function showMessage(text: string | null): void {
  messageEl.textContent = text ?? '';
  messageEl.hidden = text === null;
}

/** The server's Japanese detail when there is one, else a generic message. */
function describe(error: unknown): string {
  if (error instanceof ApiError && error.detail) return error.detail;
  console.error(error);
  return t('somethingWentWrong');
}

// ---------- Views ----------

type View = 'calculator' | 'occasions';

function show(view: View): void {
  calculatorView.hidden = view !== 'calculator';
  occasionsView.hidden = view !== 'occasions';
  const signedIn = isSignedIn();
  navCalculator.hidden = !signedIn || view === 'calculator';
  navOccasions.hidden = !signedIn || view === 'occasions';
  signInBtn.hidden = signedIn;
  signOutBtn.hidden = !signedIn;
  if (view === 'calculator') syncSuffixPadding();
  if (view === 'occasions') void loadOccasions();
}

// ---------- Calculator ----------

const state = {
  total: NaN,
  people: NaN,
  result: null as SplitResult | null,
};

function formatThousands(n: number): string {
  return Number.isFinite(n) ? n.toLocaleString('ja-JP') : '';
}

function onTotalInput(): void {
  state.total = parseNumeric(totalInput.value);
  // The cursor jumps to the end on reformat: an accepted tradeoff for simplicity.
  const formatted = formatThousands(state.total);
  if (totalInput.value !== formatted) totalInput.value = formatted;
  recompute();
}

function onPeopleInput(): void {
  state.people = parseNumeric(peopleInput.value);
  recompute();
}

totalInput.addEventListener('input', onTotalInput);
peopleInput.addEventListener('input', onPeopleInput);

function recompute(): void {
  state.result = splitBill(state.total, state.people);
  render();
}

function render(): void {
  const result = state.result;
  resultEl.textContent = result ? formatYen(result.perPerson) : '—';
  shareBtn.disabled = !result;
  surplusEl.hidden = !result || result.surplus === 0;
  surplusEl.textContent = result ? `${t('oddYenLabel')}: ${formatYen(result.surplus)}` : '';
}

shareBtn.addEventListener('click', async () => {
  if (!state.result || shareBtn.disabled) return;

  // Prevent double-tap during the picker animation
  shareBtn.disabled = true;
  try {
    await shareResult(liff, state.result);
  } finally {
    render();
  }
});

/** v1's share cards link here with ?total=…&people=…; fill them in (it never did before). */
function prefillFromUrl(): boolean {
  const params = new URLSearchParams(location.search);
  const total = params.get('total');
  const people = params.get('people');
  if (total === null && people === null) return false;
  totalInput.value = total ?? '';
  peopleInput.value = people ?? '';
  onTotalInput();
  onPeopleInput();
  return true;
}

// ---------- My occasions ----------

async function loadOccasions(): Promise<void> {
  occasionsStatus.textContent = t('loading');
  occasionList.replaceChildren();
  try {
    const occasions = await withSession(liff, myOccasions);
    occasionsStatus.textContent = occasions.length === 0 ? t('noOccasions') : '';
    occasionList.replaceChildren(
      ...occasions.map((occasion) => {
        // Opens the occasion on the website for now; the in-app screen comes in step 3.
        const link = document.createElement('a');
        link.className = 'occasion-item';
        link.href = `/groups/${encodeURIComponent(occasion.token)}`;

        const name = document.createElement('span');
        name.className = 'occasion-name';
        name.textContent = occasion.name ?? t('appTitle');

        const meta = document.createElement('span');
        meta.className = 'muted';
        meta.textContent = `${occasion.memberCount}${t('membersSuffix')} · ${t('deletesOn')} ${formatDate(occasion.deletionDate)}`;

        link.append(name, meta);
        const item = document.createElement('li');
        item.append(link);
        return item;
      }),
    );
  } catch (error) {
    occasionsStatus.textContent = '';
    showMessage(describe(error));
  }
}

// ---------- Signing in and out ----------

async function startSignIn(): Promise<void> {
  showMessage(null);
  signInBtn.disabled = true;
  try {
    if (await signIn(liff)) show('occasions');
  } catch (error) {
    showMessage(describe(error));
  } finally {
    signInBtn.disabled = false;
  }
}

signInBtn.addEventListener('click', () => void startSignIn());
signOutBtn.addEventListener('click', async () => {
  await signOut(liff);
  show('calculator');
});
navCalculator.addEventListener('click', () => show('calculator'));
navOccasions.addEventListener('click', () => show('occasions'));

// ---------- Start ----------
// A shared card opens the calculator. Otherwise: back from LINE's login page, finish signing in;
// signed in, my occasions; signed out, the calculator, as v1 always was.

if (prefillFromUrl()) {
  show('calculator');
} else if (returningFromLogin(liff)) {
  void startSignIn();
} else {
  show(isSignedIn() ? 'occasions' : 'calculator');
}
