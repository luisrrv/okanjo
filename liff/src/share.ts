/**
 * Builds the FlexMessage payload and triggers shareTargetPicker.
 *
 * The FlexMessage is what the *recipient* sees in their LINE chat — a clean,
 * card-shaped summary with the per-person amount as the headline. Recipients
 * who tap the card open Warikan with the same numbers prefilled.
 *
 * Language for the share message follows the SENDER's choice (tIn(getLang(), ...)),
 * not the recipient's. Translating per-recipient would mean knowing each one's
 * preference at send time — LIFF doesn't expose that, and the trade isn't worth
 * the complexity.
 */

import type { SplitResult } from './calc';
import { getLang, tIn, type Lang } from './i18n';

type LiffLike = {
  shareTargetPicker(messages: unknown[]): Promise<{ status: 'success' } | unknown>;
  isInClient(): boolean;
};

// LINE green — used as the card accent so the message reads as native to LINE.
const ACCENT = '#06C755';

/**
 * The deep link the recipient taps. Same origin as the app, with prefilled query params.
 * In dev, falls back to the dev URL so testing the mock end-to-end works.
 */
function buildDeepLink(result: SplitResult): string {
  const liffId = import.meta.env.VITE_LIFF_ID;
  const params = new URLSearchParams({
    total: String(result.total),
    people: String(result.people),
  });

  // Inside LINE: liff.line.me/{liffId}?... keeps the user in LIFF context.
  // Outside LINE / dev: fall back to the web origin so the link still works.
  if (liffId) {
    return `https://liff.line.me/${liffId}?${params.toString()}`;
  }

  const base = typeof window !== 'undefined' ? window.location.origin : '';
  return `${base}/?${params.toString()}`;
}

function formatYen(n: number): string {
  return `¥${n.toLocaleString('en-US')}`;
}

/**
 * Build the FlexMessage payload. Shape is documented at:
 * https://developers.line.biz/en/reference/messaging-api/#flex-message
 */
export function buildShareMessage(result: SplitResult, lang: Lang) {
  const altText = `${tIn(lang, 'shareCardHeader')}: ${formatYen(result.perPerson)} × ${result.people}`;
  const link = buildDeepLink(result);

  return {
    type: 'flex',
    altText,
    contents: {
      type: 'bubble',
      size: 'kilo',
      header: {
        type: 'box',
        layout: 'vertical',
        backgroundColor: ACCENT,
        paddingAll: '12px',
        contents: [
          {
            type: 'text',
            text: tIn(lang, 'shareCardHeader'),
            color: '#FFFFFF',
            weight: 'bold',
            size: 'sm',
          },
        ],
      },
      body: {
        type: 'box',
        layout: 'vertical',
        spacing: 'md',
        paddingAll: '16px',
        contents: [
          {
            type: 'box',
            layout: 'baseline',
            contents: [
              {
                type: 'text',
                text: tIn(lang, 'perPersonLabel'),
                size: 'sm',
                color: '#888888',
                flex: 0,
              },
            ],
          },
          {
            type: 'text',
            text: formatYen(result.perPerson),
            size: 'xxl',
            weight: 'bold',
            color: '#1A1A1A',
          },
          {
            type: 'separator',
            margin: 'md',
          },
          {
            type: 'box',
            layout: 'horizontal',
            margin: 'md',
            contents: [
              {
                type: 'text',
                text: tIn(lang, 'totalLabel'),
                size: 'xs',
                color: '#888888',
              },
              {
                type: 'text',
                text: formatYen(result.total),
                size: 'xs',
                color: '#1A1A1A',
                align: 'end',
              },
            ],
          },
          {
            type: 'box',
            layout: 'horizontal',
            contents: [
              {
                type: 'text',
                text: tIn(lang, 'peopleLabel'),
                size: 'xs',
                color: '#888888',
              },
              {
                type: 'text',
                text: `${result.people}${tIn(lang, 'people') === '人' ? '人' : ` ${tIn(lang, 'people')}`}`,
                size: 'xs',
                color: '#1A1A1A',
                align: 'end',
              },
            ],
          },
        ],
      },
      footer: {
        type: 'box',
        layout: 'vertical',
        paddingAll: '8px',
        contents: [
          {
            type: 'button',
            style: 'link',
            height: 'sm',
            action: {
              type: 'uri',
              label: tIn(lang, 'shareCardOpen'),
              uri: link,
            },
          },
        ],
      },
    },
  };
}

/**
 * Open the LINE share-target picker with our message. Returns true on success,
 * false on user cancel or any error. Caller decides what UX to show.
 */
export async function shareResult(liff: LiffLike, result: SplitResult): Promise<boolean> {
  if (!liff.isInClient()) {
    alert(getLang() === 'ja'
      ? 'この機能はLINEアプリ内でのみ利用できます'
      : 'Sharing only works inside the LINE app.');
    return false;
  }

  const lang = getLang();
  const message = buildShareMessage(result, lang);

  try {
    await liff.shareTargetPicker([message]);
    return true;
  } catch (err) {
    console.warn('[share] picker closed or failed:', err);
    return false;
  }
}