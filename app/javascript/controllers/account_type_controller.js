import { Controller } from "@hotwired/stimulus"

// Re-words the sign-up form when somebody picks Business or Creator.
//
// A creator has no "business name", and being asked for one on the first
// screen is the moment they decide the product was not built for them. The
// choice therefore changes the language immediately rather than after sign-up.
//
// Progressive enhancement: the form works untouched with no JavaScript. The
// radio still posts, the server still records the type, and the labels simply
// keep their business wording -- which is the honest default, since that is
// what the radio is set to.
export default class extends Controller {
  static targets = ["label", "field", "hint"]
  static values = {
    business: Object,   // { label, placeholder, hint }
    influencer: Object
  }

  connect() {
    this.apply()
  }

  // Fired by the radios. Reading the checked radio rather than the event
  // target means keyboard arrow-keys, which move the selection without a
  // click, are handled by the same path.
  change() {
    this.apply()
  }

  apply() {
    const chosen = this.element.querySelector('input[name="user[account_type]"]:checked')
    const words = chosen?.value === "influencer" ? this.influencerValue : this.businessValue
    if (!words) return

    if (this.hasLabelTarget) this.labelTarget.textContent = words.label
    if (this.hasFieldTarget) {
      this.fieldTarget.placeholder = words.placeholder
      // The label is visually hidden here, so the accessible name has to come
      // along or a screen reader keeps announcing the old wording.
      this.fieldTarget.setAttribute("aria-label", words.label)
    }
    if (this.hasHintTarget) this.hintTarget.textContent = words.hint
  }
}
