/**
 * The occasion screens (ADR 0024, D2). They only render what the server computed and call back
 * for actions; main.ts owns navigation, sessions and API calls.
 */

import { ApiError, type FieldErrors, type Member, type NewExpense, type Occasion } from './api';
import { guardImeEnter, h } from './dom';
import { formatYen, parseNumeric } from './format';
import { t } from './i18n';

// ---------- Field errors ----------

/** Shows the server's per-field messages under their fields; returns false if none matched. */
function showFieldErrors(form: HTMLFormElement, errors: FieldErrors): boolean {
  form.querySelectorAll('.field-error').forEach((el) => el.remove());
  let shown = false;
  for (const [field, messages] of Object.entries(errors)) {
    const anchor = form.querySelector(`[data-field="${field}"]`);
    if (!anchor || messages.length === 0) continue;
    anchor.append(h('p', { class: 'field-error' }, messages.map((m) => m.message).join(' ')));
    shown = true;
  }
  return shown;
}

/**
 * Submits a form through `action`, showing validation errors under fields and anything else
 * through `fail`. The submit button is disabled while it runs.
 */
function wireForm(form: HTMLFormElement, action: () => Promise<void>, fail: (error: unknown) => void): void {
  guardImeEnter(form);
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = form.querySelector<HTMLButtonElement>('button[type="submit"]');
    if (button) button.disabled = true;
    try {
      await action();
    } catch (error) {
      if (!(error instanceof ApiError && showFieldErrors(form, error.fieldErrors))) fail(error);
    } finally {
      if (button) button.disabled = false;
    }
  });
}

/** The label wraps its input, so the input is named for screen readers without ids. */
function field(name: string, label: string, input: HTMLElement): HTMLElement {
  return h('div', { class: 'field', 'data-field': name }, h('label', { class: 'field-label' }, h('span', { class: 'label' }, label), input));
}

function nameOf(members: Member[], id: number): string {
  return members.find((member) => member.id === id)?.name ?? '?';
}

// ---------- The occasion ----------

export type OccasionActions = {
  addExpense(): void;
  addMember(name: string, claim: boolean): Promise<void>;
  claim(memberId: number): Promise<void>;
  share(): void;
  fail(error: unknown): void;
};

export function renderOccasion(occasion: Occasion, actions: OccasionActions): HTMLElement {
  const { members, expenses, settlement } = occasion;
  const canClaim = occasion.myMemberId === null;

  const memberItems = members.map((member) =>
    h(
      'li',
      { class: 'row' },
      h('span', {}, member.name),
      member.mine
        ? h('span', { class: 'tag' }, t('me'))
        : canClaim && !member.claimed
          ? claimButton(member)
          : null,
    ),
  );

  function claimButton(member: Member): HTMLButtonElement {
    const button = h('button', { type: 'button', class: 'nav-btn' }, t('claim'));
    button.addEventListener('click', async () => {
      button.disabled = true;
      await actions.claim(member.id).catch(actions.fail);
      button.disabled = false;
    });
    return button;
  }

  const memberName = h('input', { class: 'input text-input', autocomplete: 'off', required: true, maxlength: 50 });
  const asMe = h('input', { type: 'checkbox' });
  const addMemberForm = h(
    'form',
    { class: 'inline-form' },
    field('name', t('addMember'), memberName),
    canClaim ? h('label', { class: 'check' }, asMe, t('addMemberAsMe')) : null,
    h('button', { type: 'submit', class: 'nav-btn' }, t('add')),
  );
  wireForm(addMemberForm, () => actions.addMember(memberName.value.trim(), asMe.checked), actions.fail);

  const expenseItems = expenses.map((expense) =>
    h(
      'li',
      { class: 'card' },
      h('div', { class: 'row' }, h('strong', {}, expense.description), h('strong', {}, formatYen(expense.amount))),
      h(
        'p',
        { class: 'muted' },
        `${t('perPersonLabel')} ${formatYen(expense.shareAmount)} × ${expense.memberIds.length}${t('people')} · ${t('paidBy')}: ${nameOf(members, expense.payerId)}${t('honorific')}`,
      ),
    ),
  );

  const collector = settlement.collectorId === null ? null : nameOf(members, settlement.collectorId);
  const transfers = settlement.transfers.map((transfer) =>
    h(
      'li',
      { class: 'row' },
      h('span', {}, `${nameOf(members, transfer.fromId)}${t('honorific')} → ${nameOf(members, transfer.toId)}${t('honorific')}`),
      h('strong', {}, formatYen(transfer.amount)),
    ),
  );

  const addExpenseButton = h('button', { type: 'button', class: 'share-btn' }, t('addExpense'));
  addExpenseButton.addEventListener('click', actions.addExpense);
  addExpenseButton.disabled = members.length === 0;

  const shareButton = h('button', { type: 'button', class: 'nav-btn' }, t('shareButton'));
  shareButton.addEventListener('click', actions.share);

  return h(
    'div',
    { class: 'view' },
    h('h2', { class: 'view-title' }, occasion.name ?? t('appTitle')),
    h('section', { class: 'card' }, h('h3', { class: 'section-title' }, t('settlement')),
      collector ? h('p', { class: 'muted' }, `${collector}${t('collectorSuffix')}`) : h('p', { class: 'muted' }, t('settledUp')),
      transfers.length > 0 ? h('ul', { class: 'plain-list' }, ...transfers) : null),
    addExpenseButton,
    h('section', {}, h('h3', { class: 'section-title' }, t('expenses')),
      expenseItems.length > 0 ? h('ul', { class: 'plain-list' }, ...expenseItems) : h('p', { class: 'muted' }, t('noExpenses'))),
    h('section', { class: 'card' }, h('h3', { class: 'section-title' }, t('members')),
      h('ul', { class: 'plain-list' }, ...memberItems), addMemberForm),
    h('div', { class: 'row' }, shareButton,
      h('a', { class: 'nav-btn', href: `/groups/${encodeURIComponent(occasion.token)}` }, t('editOnWeb'))),
  );
}

// ---------- Adding an expense ----------

export function renderExpenseForm(
  occasion: Occasion,
  submit: (expense: NewExpense) => Promise<void>,
  cancel: () => void,
  fail: (error: unknown) => void,
): HTMLElement {
  const description = h('input', { class: 'input text-input', autocomplete: 'off', required: true, maxlength: 100 });
  const amount = h('input', { class: 'input', inputmode: 'numeric', autocomplete: 'off', required: true });
  const payer = h(
    'select',
    { class: 'input text-input' },
    ...occasion.members.map((member) => h('option', { value: member.id }, member.name)),
  );
  // You by default, else the first member (ADR 0015's website defaults).
  payer.value = String(occasion.myMemberId ?? occasion.members[0]?.id ?? '');

  const splitBoxes = occasion.members.map((member) => ({
    member,
    box: h('input', { type: 'checkbox', checked: true }),
  }));

  const cancelButton = h('button', { type: 'button', class: 'nav-btn' }, t('cancel'));
  cancelButton.addEventListener('click', cancel);

  const form = h(
    'form',
    { class: 'view' },
    h('h2', { class: 'view-title' }, t('addExpense')),
    field('description', t('description'), description),
    field('amount', t('amount'), amount),
    field('payer_id', t('paidBy'), payer),
    h(
      'div',
      { class: 'field', 'data-field': 'member_ids' },
      h('span', { class: 'label' }, t('splitAmong')),
      ...splitBoxes.map(({ member, box }) => h('label', { class: 'check' }, box, member.name)),
    ),
    h('button', { type: 'submit', class: 'share-btn' }, t('save')),
    cancelButton,
  );

  wireForm(
    form,
    () =>
      submit({
        description: description.value.trim(),
        // NaN stays NaN and the server answers with the field's error; nothing is rounded here.
        amount: parseNumeric(amount.value),
        payerId: Number(payer.value),
        memberIds: splitBoxes.filter(({ box }) => box.checked).map(({ member }) => member.id),
      }),
    fail,
  );
  return form;
}

// ---------- A new occasion ----------

export function renderNewOccasionForm(
  defaultName: string,
  submit: (name: string, memberName: string) => Promise<void>,
  cancel: () => void,
  fail: (error: unknown) => void,
): HTMLElement {
  const name = h('input', { class: 'input text-input', autocomplete: 'off', maxlength: 50, placeholder: '飲み会' });
  const memberName = h('input', { class: 'input text-input', autocomplete: 'off', required: true, maxlength: 50, value: defaultName });

  const cancelButton = h('button', { type: 'button', class: 'nav-btn' }, t('cancel'));
  cancelButton.addEventListener('click', cancel);

  const form = h(
    'form',
    { class: 'view' },
    h('h2', { class: 'view-title' }, t('newOccasion')),
    field('name', t('occasionName'), name),
    field('member_name', t('yourName'), memberName),
    h('button', { type: 'submit', class: 'share-btn' }, t('create')),
    cancelButton,
  );
  wireForm(form, () => submit(name.value.trim(), memberName.value.trim()), fail);
  return form;
}

// ---------- Linking an email account ----------

export function renderLinkEmailForm(
  submit: (emailAddress: string, password: string) => Promise<void>,
  cancel: () => void,
  fail: (error: unknown) => void,
): HTMLElement {
  const email = h('input', { class: 'input text-input', type: 'email', autocomplete: 'username', required: true });
  const password = h('input', { class: 'input text-input', type: 'password', autocomplete: 'current-password', required: true });

  const cancelButton = h('button', { type: 'button', class: 'nav-btn' }, t('cancel'));
  cancelButton.addEventListener('click', cancel);

  const form = h(
    'form',
    { class: 'view' },
    h('h2', { class: 'view-title' }, t('linkEmail')),
    h('p', { class: 'muted' }, t('linkEmailNote')),
    field('email_address', t('emailAddress'), email),
    field('password', t('password'), password),
    h('button', { type: 'submit', class: 'share-btn' }, t('link')),
    cancelButton,
  );
  wireForm(form, () => submit(email.value.trim(), password.value), fail);
  return form;
}
