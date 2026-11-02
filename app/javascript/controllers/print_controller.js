import { Controller } from "@hotwired/stimulus"

// Opens the browser's print dialog, where "Save as PDF" makes the receipt file (ADR 0016).
export default class extends Controller {
  print() {
    window.print()
  }
}
