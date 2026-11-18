const yenFormat = new Intl.NumberFormat('ja-JP', { style: 'currency', currency: 'JPY' });

/** ¥1,500, the Japanese way: no decimals. */
export function formatYen(amount: number): string {
  return yenFormat.format(amount);
}

/**
 * Digits only, after turning full-width characters into half-width ones (NFKC), so ４５００ typed
 * with a Japanese keyboard counts. NaN when nothing numeric is left.
 */
export function parseNumeric(raw: string): number {
  const cleaned = raw.normalize('NFKC').replace(/[^\d]/g, '');
  return cleaned === '' ? NaN : Number(cleaned);
}

/** 2026-12-02 → 12月2日 */
export function formatDate(isoDate: string): string {
  const [, month, day] = isoDate.split('-').map(Number);
  return `${month}月${day}日`;
}
