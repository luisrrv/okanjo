import { Controller } from "@hotwired/stimulus"

// Asks for confirmation whenever the payer ends up left out of the split, by
// unticking them or by choosing a payer who isn't ticked (ADR 0015). Cancel
// puts the payer back in. The amounts shown are a preview; the server computes
// the real shares. All wording comes from ja.yml through the values below.
export default class extends Controller {
  static targets = [ "payer", "member", "amount" ]
  static values = { message: String, messageWithoutAmount: String, name: String, separator: String, currency: String }

  payerChanged() {
    this.confirmIfPayerLeftOut()
  }

  memberChanged(event) {
    if (event.target.value === this.payerTarget.value) this.confirmIfPayerLeftOut()
  }

  confirmIfPayerLeftOut() {
    const payerBox = this.memberTargets.find((box) => box.value === this.payerTarget.value)
    if (!payerBox || payerBox.checked) return

    if (!window.confirm(this.messageFor(payerBox.dataset.name))) payerBox.checked = true
  }

  messageFor(payer) {
    const others = this.memberTargets.filter((box) => box.checked).map((box) => box.dataset.name)
    const amount = parseInt(this.amountTarget.value, 10)
    if (!amount || others.length === 0) return this.messageWithoutAmountValue.replace("%{payer}", payer)

    return this.messageValue
      .replace("%{payer}", payer)
      .replace("%{others}", others.map((name) => this.nameValue.replace("%{name}", name)).join(this.separatorValue))
      .replace("%{amount}", this.yen(amount))
      .replace("%{share}", this.yen(Math.ceil(amount / others.length)))
  }

  yen(amount) {
    return this.currencyValue.replace("%{amount}", amount.toLocaleString("ja-JP"))
  }
}
