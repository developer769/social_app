import { Controller } from "@hotwired/stimulus"

// The upload dropzone on the post form.
//
// The label already said "Drag and drop, or click to choose a file" while
// nothing implemented dropping, and the input is visually hidden, so choosing
// a file changed nothing on screen. Between the two, the honest reading of
// that box was that uploading did not work -- it did, silently.
//
// This makes the promise true and, more importantly, makes the result visible.
// It is progressive enhancement over a plain file input: with no JavaScript the
// label still opens the file picker and the form still submits.
export default class extends Controller {
  static targets = ["input", "prompt", "detail", "preview", "error"]
  static values = {
    imageMax: Number,
    videoMax: Number,
    imageTypes: Array,
    videoTypes: Array
  }
  static classes = ["active"]

  connect() {
    this.dragDepth = 0
  }

  disconnect() {
    this.releasePreview()
  }

  // ── Drag and drop ────────────────────────────────────────────────────────
  // dragenter/dragleave fire for every child element the pointer crosses, so a
  // plain boolean flickers. Counting depth is what keeps the highlight steady.
  dragEnter(event) {
    event.preventDefault()
    this.dragDepth += 1
    this.setActive(true)
  }

  dragOver(event) {
    // Without preventDefault on dragover the browser refuses the drop and
    // opens the file in a new tab instead.
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
  }

  dragLeave(event) {
    event.preventDefault()
    this.dragDepth = Math.max(0, this.dragDepth - 1)
    if (this.dragDepth === 0) this.setActive(false)
  }

  drop(event) {
    event.preventDefault()
    this.dragDepth = 0
    this.setActive(false)

    const file = event.dataTransfer?.files?.[0]
    if (!file) return

    // Assigning a DataTransfer's FileList is the only way to put a dropped
    // file into a file input; constructing one by hand is not permitted.
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files

    // Assigning .files does not fire change, and the rest of the page (and any
    // future listener) has no other way to know.
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  // ── Selection ────────────────────────────────────────────────────────────
  selected() {
    const file = this.inputTarget.files?.[0]
    this.releasePreview()
    this.clearError()

    if (!file) return this.reset()

    const problem = this.validate(file)
    if (problem) {
      // The file is cleared rather than left in place: leaving a rejected file
      // in the input means the form posts it anyway, and the server's refusal
      // arrives after a long upload of something already known to be wrong.
      this.inputTarget.value = ""
      this.reset()
      return this.showError(problem)
    }

    this.show(file)
  }

  validate(file) {
    const video = this.videoTypesValue.includes(file.type)
    const image = this.imageTypesValue.includes(file.type)

    if (!video && !image) {
      return `${file.name} is a ${this.describeType(file)}. Choose a JPG, PNG or WebP picture, or an MP4, MOV or WebM video.`
    }

    const max = video ? this.videoMaxValue : this.imageMaxValue
    if (max && file.size > max) {
      return `${file.name} is ${this.humanSize(file.size)}. The limit for a ${video ? "video" : "picture"} is ${this.humanSize(max)}.`
    }

    return null
  }

  show(file) {
    const kind = this.videoTypesValue.includes(file.type) ? "Video" : "Picture"
    if (this.hasPromptTarget) this.promptTarget.textContent = "Ready to upload"
    if (this.hasDetailTarget) {
      this.detailTarget.textContent = `${kind} · ${file.name} · ${this.humanSize(file.size)}`
    }

    if (this.hasPreviewTarget && file.type.startsWith("image/")) {
      this.previewUrl = URL.createObjectURL(file)
      this.previewTarget.src = this.previewUrl
      this.previewTarget.hidden = false
    }
  }

  reset() {
    if (this.hasPromptTarget) this.promptTarget.textContent = this.promptTarget.dataset.default || ""
    if (this.hasDetailTarget) this.detailTarget.textContent = this.detailTarget.dataset.default || ""
    if (this.hasPreviewTarget) {
      this.previewTarget.hidden = true
      this.previewTarget.removeAttribute("src")
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  setActive(on) {
    if (!this.hasActiveClass) return
    this.element.classList.toggle(this.activeClass, on)
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
  }

  // An object URL holds the whole file in memory until it is revoked, and this
  // form can be used repeatedly without a page load.
  releasePreview() {
    if (!this.previewUrl) return
    URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }

  describeType(file) {
    if (!file.type) return "file of an unknown type"
    if (file.type.startsWith("image/")) return `${file.type.split("/")[1].toUpperCase()} image, which is not supported`
    if (file.type.startsWith("video/")) return `${file.type.split("/")[1].toUpperCase()} video, which is not supported`
    return file.type
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} bytes`
    const mb = bytes / (1024 * 1024)
    if (mb < 1) return `${Math.round(bytes / 1024)} KB`
    return `${mb >= 10 ? Math.round(mb) : mb.toFixed(1)} MB`
  }
}
