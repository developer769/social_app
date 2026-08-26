import { Controller } from "@hotwired/stimulus"

// The detail card that appears over a calendar entry.
//
// Hover is not the only way in. A calendar full of hover-only detail is unusable
// with a keyboard and invisible on a phone, so this opens on focus as well, and
// closes on Escape (WCAG 2.2, 1.4.13: dismissible, hoverable, persistent).
// On touch there is no hover at all -- the entry is a link, and tapping it opens
// the post's own page, which carries the same detail.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.hideTimer = null
    this.onKeydown = (event) => {
      if (event.key === "Escape") this.hide()
    }
  }

  disconnect() {
    this.clearTimer()
    document.removeEventListener("keydown", this.onKeydown)
  }

  show() {
    this.clearTimer()
    if (!this.hasPanelTarget) return

    this.panelTarget.hidden = false
    this.position()
    document.addEventListener("keydown", this.onKeydown)
  }

  // A small delay, so moving the pointer from the entry onto the card itself
  // does not dismiss the thing you are reaching for.
  scheduleHide() {
    this.clearTimer()
    this.hideTimer = setTimeout(() => this.hide(), 120)
  }

  hide() {
    this.clearTimer()
    if (!this.hasPanelTarget) return

    this.panelTarget.hidden = true
    document.removeEventListener("keydown", this.onKeydown)
  }

  clearTimer() {
    if (this.hideTimer) clearTimeout(this.hideTimer)
    this.hideTimer = null
  }

  // Fixed rather than absolute: a month cell clips its overflow, and a card
  // anchored inside one would be cut off at the cell edge.
  position() {
    const trigger = this.element.getBoundingClientRect()
    const panel = this.panelTarget
    const width = panel.offsetWidth
    const height = panel.offsetHeight
    const margin = 8

    // Prefer the right of the entry, flip left when it would run off screen.
    let left = trigger.right + margin
    if (left + width > window.innerWidth - margin) left = trigger.left - width - margin
    if (left < margin) left = margin

    // Vertically centred on the entry, then pulled back inside the viewport.
    let top = trigger.top + trigger.height / 2 - height / 2
    if (top + height > window.innerHeight - margin) top = window.innerHeight - height - margin
    if (top < margin) top = margin

    panel.style.left = `${Math.round(left)}px`
    panel.style.top = `${Math.round(top)}px`
  }
}
