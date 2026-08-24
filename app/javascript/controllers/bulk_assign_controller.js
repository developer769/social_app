import { Controller } from "@hotwired/stimulus"

// Two conveniences on the batch review screen.
export default class extends Controller {
  static targets = ["subject"]

  // Filling thirty selects one at a time is the reason people abandon a batch.
  applyAll(event) {
    const value = event.target.value
    if (!value) return

    this.subjectTargets.forEach((select) => { select.value = value })
  }

  // Changing the start date changes every slot, so the dates are recomputed on
  // the server rather than guessed at in the browser.
  restart(event) {
    const url = new URL(window.location.href)
    url.searchParams.set("starting", event.target.value)
    window.location.assign(url.toString())
  }
}
