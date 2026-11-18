/**
 * The app's copy, in one place. Japanese only (ADR 0024, D7, following ADR 0018); the API's
 * problem `code`s leave room for other languages later.
 */

const ja = {
  appTitle: '割り勘',
  totalLabel: '合計金額',
  peopleLabel: '人数',
  perPersonLabel: '一人あたり',
  oddYenLabel: 'お釣り（立て替えた人へ）',
  yen: '円',
  people: '人',
  shareButton: 'チャットに送る',
  placeholderTotal: '例: 4500',
  placeholderPeople: '例: 3',
  shareCardHeader: '割り勘',
  shareCardOpen: '割り勘を開く',
  shareOnlyInLine: 'この機能はLINEアプリ内でのみ利用できます',
  signIn: 'LINEでログイン',
  signOut: 'ログアウト',
  calculator: '計算',
  myOccasions: '自分の割り勘',
  noOccasions: 'まだ割り勘はありません',
  loading: '読み込み中…',
  membersSuffix: '人',
  deletesOn: '削除予定',
  somethingWentWrong: 'うまくいきませんでした。しばらくしてからもう一度お試しください',
  members: 'メンバー',
  me: '自分',
  claim: 'これは私',
  addMember: 'メンバーを追加',
  addMemberAsMe: '自分として追加',
  add: '追加',
  expenses: '支払い',
  noExpenses: '支払いはまだありません',
  addExpense: '支払いを追加',
  settlement: '精算',
  settledUp: '精算するものはありません',
  collectorSuffix: 'さんがまとめて精算します',
  honorific: 'さん',
  paidBy: '支払った人',
  editOnWeb: 'ウェブで編集',
  newOccasion: '新しい割り勘',
  occasionName: '割り勘の名前（任意）',
  yourName: 'あなたの名前',
  create: '作成する',
  description: '内容',
  amount: '金額',
  splitAmong: '割り勘する人',
  save: '追加する',
  cancel: 'キャンセル',
  linkEmail: 'メールアカウントと連携',
  linkEmailNote: 'ウェブで作ったアカウントと連携すると、同じ割り勘をLINEとウェブの両方で使えます。',
  emailAddress: 'メールアドレス',
  password: 'パスワード',
  link: '連携する',
  linked: '連携しました',
  occasionGone: 'この割り勘は見つかりませんでした。削除された可能性があります。',
  signInToOpen: 'LINEでログインすると、この割り勘を開けます',
  back: '戻る',
} as const;

export type StringKey = keyof typeof ja;

export function t(key: StringKey): string {
  return ja[key];
}
