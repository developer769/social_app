import { Controller } from "@hotwired/stimulus"

// Tells somebody the two passwords differ before they submit.
//
// The server checks this too, and that check is the one that counts. This is
// about what a mismatch costs to recover from: browsers clear password fields
// when a form re-renders, so being told after submitting means retyping both.
//
// It reads the first password field from the form rather than taking it as a
// target, so the two fields stay independent -- each one keeps its own
// show/hide controller and neither has to know about the other's markup.
export default class extends Controller {
  static targets = ["confirmation", "message"]

  connect() {
    this.form = this.element.closest("form")
    this.original = this.form?.querySelector('input[name="user[password]"]')

    // The original field is outside this controller's element, so it cannot
    // carry a data-action for it. Without this, correcting a typo in the FIRST
    // field would leave a stale "do not match" standing under the second.
    this.recheck = () => this.check()
    this.original?.addEventListener("input", this.recheck)
  }

  disconnect() {
    this.original?.removeEventListener("input", this.recheck)
    // A custom validity left set would block the form on a later visit, since
    // Turbo can restore this page from cache with the value still on it.
    this.confirmationTarget?.setCustomValidity("")
  }

  check() {
    const confirmation = this.confirmationTarget
    const original = this.original
    if (!original) return

    // Nothing is wrong yet while the field is still being filled in, so an
    // empty confirmation is silent rather than an error.
    const mismatch = confirmation.value.length > 0 && original.value !== confirmation.value

    // setCustomValidity is what stops the form submitting and makes the
    // browser say so in its own words; the visible message below is for
    // anybody who never triggers the browser's bubble.
    confirmation.setCustomValidity(mismatch ? "Those passwords do not match." : "")

    if (this.hasMessageTarget) {
      this.messageTarget.textContent = mismatch ? "Those passwords do not match." : ""
      this.messageTarget.hidden = !mismatch
    }
  }
}
