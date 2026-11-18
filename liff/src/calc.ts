/**
 * Splits a total amount across N people, rounding each share UP to the nearest ¥100.
 *
 * The ¥100 rounding is the JP cultural convention for warikan — nobody asks for ¥17.
 * Rounding up (rather than nearest) means the organizer never ends up short.
 *
 * Returns null for invalid input (zero/negative people, negative total, NaN).
 * The caller decides how to display "no result yet" — separation of concerns.
 */
export type SplitResult = {
  perPerson: number;
  total: number;
  people: number;
  /** perPerson * people; equals or exceeds `total` because of round-up. */
  collected: number;
  /** collected - total; what the organizer pockets from the rounding. */
  surplus: number;
};

export function splitBill(total: number, people: number): SplitResult | null {
  if (!Number.isFinite(total) || !Number.isFinite(people)) return null;
  if (total < 0 || people < 1) return null;
  if (!Number.isInteger(people)) return null;

  const rawShare = total / people;
  const perPerson = Math.ceil(rawShare / 100) * 100;
  const collected = perPerson * people;
  const surplus = collected - total;

  return { perPerson, total, people, collected, surplus };
}
