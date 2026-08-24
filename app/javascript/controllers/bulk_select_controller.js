import { Controller } from "@hotwired/stimulus"

// Keeps the running count honest and stops an empty batch being submitted.
//
// The cap is enforced on the server as well; this only saves somebody from
// selecting forty things and being told no at the end.
export default class extends Controller {
  static targets = ["count", "summary", "submit"]
  static values = { max: { type: Number, default: 30 } }

  connect() {
    this.refresh()
  }

  toggle() {
    this.refresh()
  }

  refresh() {
    const boxes = this.element.querySelectorAll('input[name="template_ids[]"]')
    const chosen = [...boxes].filter((box) => box.checked)
    const count = chosen.length

    if (count >= this.maxValue) {
      boxes.forEach((box) => { box.disabled = !box.checked })
    } else {
      boxes.forEach((box) => { box.disabled = false })
    }

    if (this.hasCountTarget) this.countTarget.textContent = count

    if (this.hasSummaryTarget) {
      this.summaryTarget.textContent =
        count === 0
          ? "Nothing chosen yet"
          : `${count} ${count === 1 ? "style" : "styles"} chosen${count >= this.maxValue ? " — that is the most in one batch" : ""}`
    }

    if (this.hasSubmitTarget) this.submitTarget.disabled = count === 0
  }
}
