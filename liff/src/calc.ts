/**
 * Splits a total across N people, rounding each share UP to the yen: the same rule as the
 * server's Expense#share_amount (ADR 0008), so the calculator and occasions agree (ADR 0024, D1).
 * The person who paid keeps the odd yen.
 *
 * Returns null for invalid input (zero or negative people, a negative total, NaN). The caller
 * decides how to show "no result yet".
 */
export type SplitResult = {
  perPerson: number;
  total: number;
  people: number;
  /** perPerson * people; equals or exceeds `total` because of the round-up. */
  collected: number;
  /** collected - total: the odd yen the payer keeps. */
  surplus: number;
};

export function splitBill(total: number, people: number): SplitResult | null {
  if (!Number.isFinite(total) || !Number.isFinite(people)) return null;
  if (total < 0 || people < 1) return null;
  if (!Number.isInteger(total) || !Number.isInteger(people)) return null;

  const perPerson = Math.ceil(total / people);
  const collected = perPerson * people;
  const surplus = collected - total;

  return { perPerson, total, people, collected, surplus };
}
