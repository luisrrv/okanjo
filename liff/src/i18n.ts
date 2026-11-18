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
} as const;

export type StringKey = keyof typeof ja;

export function t(key: StringKey): string {
  return ja[key];
}
