import { Controller } from "@hotwired/stimulus"

// Show / hide the password.
//
// The field already had a padlock at the end of its line, and a padlock beside
// a password field reads as "click to reveal" whether or not anything is
// listening. It was decorative, so clicking it did nothing -- which is worse
// than having no icon at all, because it looks broken rather than absent.
//
// The decorative lock is what the server renders; this swaps it for a real
// button on connect. With no JavaScript the line looks exactly as it did,
// rather than offering a control that cannot work.
export default class extends Controller {
  static targets = ["field", "button", "decor", "eye", "eyeOff"]

  connect() {
    if (!this.hasFieldTarget || !this.hasButtonTarget) return

    this.decorTarget.hidden = true
    this.buttonTarget.hidden = false
  }

  disconnect() {
    // Turbo caches pages. Leaving a revealed password in the cached copy would
    // put it on screen again for whoever opens that tab next.
    if (this.hasFieldTarget && this.fieldTarget.type === "text") this.conceal()
  }

  toggle() {
    this.fieldTarget.type === "password" ? this.reveal() : this.conceal()
  }

  reveal() {
    this.swap("text", "Hide password")
  }

  conceal() {
    this.swap("password", "Show password")
  }

  swap(type, label) {
    // Changing an input's type drops the caret to the end in several browsers,
    // so the selection is put back. Somebody correcting a typo mid-password
    // should not lose their place for looking at it.
    const { selectionStart, selectionEnd } = this.fieldTarget
    const focused = document.activeElement === this.fieldTarget

    this.fieldTarget.type = type

    if (focused) {
      this.fieldTarget.focus()
      try {
        this.fieldTarget.setSelectionRange(selectionStart, selectionEnd)
      } catch {
        // Some browsers refuse setSelectionRange on certain input types; the
        // field is still usable, the caret just sits at the end.
      }
    }

    const revealed = type === "text"
    this.eyeTarget.hidden = revealed
    this.eyeOffTarget.hidden = !revealed
    this.buttonTarget.setAttribute("aria-label", label)
    this.buttonTarget.setAttribute("aria-pressed", String(revealed))
  }
}
