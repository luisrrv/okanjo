/**
 * Builds elements without HTML strings: text always goes in through text nodes, so names people
 * typed can't become markup.
 */

type Child = Node | string | number | null | undefined | false;
type Attrs = Record<string, string | number | boolean | null | undefined>;

export function h<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Attrs = {}, ...children: Child[]): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [name, value] of Object.entries(attrs)) {
    if (value === false || value === null || value === undefined) continue;
    el.setAttribute(name, value === true ? '' : String(value));
  }
  for (const child of children) {
    if (child === false || child === null || child === undefined) continue;
    el.append(child instanceof Node ? child : String(child));
  }
  return el;
}

/**
 * Stops Enter from submitting while a Japanese IME is converting (confirming 漢字 with Enter).
 * Some browsers, Safari among them, report that keypress as a plain Enter.
 */
export function guardImeEnter(form: HTMLFormElement): void {
  form.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && (event.isComposing || event.keyCode === 229)) event.preventDefault();
  });
}
