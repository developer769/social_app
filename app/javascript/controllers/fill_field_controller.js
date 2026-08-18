import { Controller } from "@hotwired/stimulus"

// Quick-add chips drop a suggestion into the name field and move focus there,
// so the owner can keep typing rather than hunting for the input.
export default class extends Controller {
  static values = { target: String, text: String }

  apply() {
    const field = document.getElementById(this.targetValue)
    if (!field) return

    field.value = this.textValue
    field.focus()
    field.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
