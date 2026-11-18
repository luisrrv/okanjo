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
import { shareOccasion, shareResult } from './share';
import * as api from './api';
import { ApiError, type Occasion } from './api';
import { isSignedIn, linkEmail, returningFromLogin, signIn, signOut, withSession } from './auth';
import { renderExpenseForm, renderLinkEmailForm, renderNewOccasionForm, renderOccasion } from './occasion';
import { h } from './dom';

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
const screen = $<HTMLElement>('#screen');
const occasionList = $<HTMLUListElement>('#occasion-list');
const occasionsStatus = $<HTMLParagraphElement>('#occasions-status');
const newOccasionBtn = $<HTMLButtonElement>('#new-occasion');
const linkEmailBtn = $<HTMLButtonElement>('#link-email');
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

const fail = (error: unknown): void => showMessage(describe(error));
const session = <T>(call: () => Promise<T>): Promise<T> => withSession(liff, call);

// ---------- Views ----------
// The calculator and my occasions are fixed sections; an occasion and its forms are built into
// #screen.

type View = 'calculator' | 'occasions' | 'screen';

function show(view: View): void {
  calculatorView.hidden = view !== 'calculator';
  occasionsView.hidden = view !== 'occasions';
  screen.hidden = view !== 'screen';
  if (view !== 'screen') current = null;
  const signedIn = isSignedIn();
  navCalculator.hidden = !signedIn || view === 'calculator';
  navOccasions.hidden = !signedIn || view === 'occasions';
  signInBtn.hidden = signedIn;
  signOutBtn.hidden = !signedIn;
  if (view === 'calculator') syncSuffixPadding();
  if (view === 'occasions') void loadOccasions();
  window.scrollTo(0, 0);
}

function showScreen(content: HTMLElement): void {
  screen.replaceChildren(content);
  show('screen');
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
function prefillFromUrl(params: URLSearchParams): boolean {
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
    const [occasions, user] = await session(() => Promise.all([api.myOccasions(), api.me()]));
    linkEmailBtn.hidden = user.emailAddress !== null;
    occasionsStatus.textContent = occasions.length === 0 ? t('noOccasions') : '';
    occasionList.replaceChildren(
      ...occasions.map((occasion) => {
        const button = h(
          'button',
          { type: 'button', class: 'occasion-item' },
          h('span', { class: 'occasion-name' }, occasion.name ?? t('appTitle')),
          h(
            'span',
            { class: 'muted' },
            `${occasion.memberCount}${t('membersSuffix')} · ${t('deletesOn')} ${formatDate(occasion.deletionDate)}`,
          ),
        );
        button.addEventListener('click', () => void openOccasion(occasion.token));
        return h('li', {}, button);
      }),
    );
  } catch (error) {
    occasionsStatus.textContent = '';
    fail(error);
  }
}

newOccasionBtn.addEventListener('click', async () => {
  showMessage(null);
  // Your LINE name by default (the profile scope); typing it works too.
  const profile = await liff.getProfile().catch(() => null);
  showScreen(
    renderNewOccasionForm(
      profile?.displayName ?? '',
      async (name, memberName) => {
        const occasion = await session(() => api.createOccasion(name, memberName));
        await openOccasion(occasion.token);
      },
      () => show('occasions'),
      fail,
    ),
  );
});

linkEmailBtn.addEventListener('click', () => {
  showMessage(null);
  showScreen(
    renderLinkEmailForm(
      async (emailAddress, password) => {
        await linkEmail(liff, emailAddress, password);
        show('occasions');
        showMessage(null);
        alert(t('linked'));
      },
      () => show('occasions'),
      fail,
    ),
  );
});

// ---------- An occasion ----------
// Re-read with If-None-Match when the app comes back into view and after every write, so other
// people's changes show up (there are no pushes to API clients, ADR 0023).

let current: { token: string; etag: string | null; occasion: Occasion } | null = null;

async function openOccasion(token: string): Promise<void> {
  showMessage(null);
  try {
    const loaded = await session(() => api.getOccasion(token));
    if (!loaded) return;
    current = { token, etag: loaded.etag, occasion: loaded.occasion };
    showScreen(occasionScreen(loaded.occasion));
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) {
      show('occasions');
      showMessage(t('occasionGone'));
    } else {
      fail(error);
    }
  }
}

async function refreshOccasion(): Promise<void> {
  if (!current || screen.hidden) return;
  const { token, etag } = current;
  const loaded = await session(() => api.getOccasion(token, etag ?? undefined)).catch(() => null);
  if (!loaded || current?.token !== token) return;
  current = { token, etag: loaded.etag, occasion: loaded.occasion };
  screen.replaceChildren(occasionScreen(loaded.occasion));
}

function occasionScreen(occasion: Occasion): HTMLElement {
  return renderOccasion(occasion, {
    addExpense: () =>
      showScreen(
        renderExpenseForm(
          occasion,
          async (expense) => {
            await session(() => api.addExpense(occasion.token, expense));
            await openOccasion(occasion.token);
          },
          () => void openOccasion(occasion.token),
          fail,
        ),
      ),
    addMember: async (name, claim) => {
      await session(() => api.addMember(occasion.token, name, claim));
      await openOccasion(occasion.token);
    },
    claim: async (memberId) => {
      await session(() => api.claimMember(occasion.token, memberId));
      await openOccasion(occasion.token);
    },
    share: () => void shareOccasion(liff, occasion),
    fail,
  });
}

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') void refreshOccasion();
});

// ---------- Signing in and out ----------

// A shared occasion opened while signed out: remembered across LINE's login page.
const PENDING_OCCASION_KEY = 'warikan-pending-occasion';

async function startSignIn(): Promise<void> {
  showMessage(null);
  signInBtn.disabled = true;
  try {
    if (!(await signIn(liff))) return;
    const pending = sessionStorage.getItem(PENDING_OCCASION_KEY);
    sessionStorage.removeItem(PENDING_OCCASION_KEY);
    if (pending) await openOccasion(pending);
    else show('occasions');
  } catch (error) {
    fail(error);
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
// Back from LINE's login page: finish signing in (and open a pending occasion). An occasion link
// opens that occasion, after signing in; a calculator link opens the calculator. Otherwise:
// signed in, my occasions; signed out, the calculator, as v1 always was.

const params = new URLSearchParams(location.search);
const occasionToken = params.get('occasion');
if (occasionToken && !isSignedIn()) sessionStorage.setItem(PENDING_OCCASION_KEY, occasionToken);

if (returningFromLogin(liff)) {
  void startSignIn();
} else if (occasionToken) {
  if (isSignedIn()) {
    void openOccasion(occasionToken);
  } else {
    show('calculator');
    showMessage(t('signInToOpen'));
  }
} else if (prefillFromUrl(params)) {
  show('calculator');
} else if (returningFromLogin(liff)) {
  void startSignIn();
} else {
  show(isSignedIn() ? 'occasions' : 'calculator');
}
