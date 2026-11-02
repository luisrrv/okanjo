import { Controller } from "@hotwired/stimulus"

// Keeps what someone is typing when another viewer's change refreshes the page by
// morphing (ADR 0019). A field is marked when edited and unmarked when its form is
// submitted, so your own submit still clears it; everything else on the page updates.
export default class extends Controller {
  mark({ target }) {
    if (target.matches("input[type=text], textarea")) target.dataset.edited = ""
  }

  unmark({ target }) {
    target.querySelectorAll("[data-edited]").forEach((field) => delete field.dataset.edited)
  }

  keep(event) {
    if (event.target.dataset?.edited !== undefined) event.preventDefault()
  }
}
