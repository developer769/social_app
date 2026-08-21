import { Controller } from "@hotwired/stimulus"

// Puts a saved reply into the reply box rather than replacing what is there:
// somebody part-way through typing must not lose it to a mis-click.
export default class extends Controller {
  insert(event) {
    const box = document.getElementById("body")
    if (!box) return

    const body = event.params.body
    box.value = box.value.trim() ? `${box.value.trim()}\n\n${body}` : body
    box.focus()
    box.setSelectionRange(box.value.length, box.value.length)
  }
}
