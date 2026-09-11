import { Controller } from "@hotwired/stimulus"

// Makes the platform marks answer the cursor.
//
// Each mark is two nested elements. The outer one follows the pointer with a
// parallax offset and a 3D tilt; the inner one runs its own drifting loop. They
// are separate because both are transforms, and one element cannot carry two
// animations without the later one overwriting the earlier.
//
// Depth is the whole illusion. A mark's `data-depth` scales how far it swings,
// how much it tilts and how fast it catches up, so the near ones lead and the
// far ones lag. Move them all by the same amount and the layer goes flat.
//
// Progressive enhancement: the CSS keyframes already float these marks. This
// takes over only once GSAP has loaded, and hands back to nothing if it fails
// -- the CSS float is still running underneath at that point.
export default class extends Controller {
  static targets = ["mark", "chip"]

  connect() {
    this.disposed = false
    this.tweens = []
    this.motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)")

    // The layer is display:none below this, so there is nothing to animate and
    // no reason to fetch GSAP for it.
    if (!window.matchMedia("(min-width: 1024px)").matches) return
    if (this.motionQuery.matches) return

    this.boot()
  }

  async boot() {
    try {
      this.gsap = (await import("gsap")).gsap
    } catch {
      return // the CSS float carries on; nothing to undo
    }
    if (this.disposed || !this.hasMarkTarget) return

    this.setters = this.markTargets.map((mark, i) => {
      const chip = this.chipTargets[i]
      const depth = parseFloat(mark.dataset.depth || "0.6")

      // GSAP takes over the drift, so the CSS keyframes have to stop or the
      // two write the same transform and fight every frame.
      if (chip) chip.style.animation = "none"

      this.driftChip(chip, depth)

      // quickTo keeps one tween per property alive and just retargets it. A
      // fresh tween per pointermove would be hundreds of tweens a second.
      const follow = 0.55 + (1 - depth) * 0.75 // far marks lag further behind
      return {
        depth,
        x: this.gsap.quickTo(mark, "x", { duration: follow, ease: "power3" }),
        y: this.gsap.quickTo(mark, "y", { duration: follow, ease: "power3" }),
        rotationY: this.gsap.quickTo(mark, "rotationY", { duration: follow, ease: "power3" }),
        rotationX: this.gsap.quickTo(mark, "rotationX", { duration: follow, ease: "power3" })
      }
    })

    // Perspective has to be on the element being rotated: without it rotationY
    // is an affine squash rather than a turn in depth.
    this.gsap.set(this.markTargets, { transformPerspective: 900, transformStyle: "preserve-3d" })

    this.onPointerMove = (event) => {
      const x = (event.clientX / window.innerWidth) * 2 - 1
      const y = (event.clientY / window.innerHeight) * 2 - 1
      this.aim(x, y)
    }
    // Rest everything when the pointer leaves the window, otherwise the layer
    // stays frozen mid-lean at whatever angle it was last pushed to.
    this.onPointerLeave = () => this.aim(0, 0)

    window.addEventListener("pointermove", this.onPointerMove, { passive: true })
    document.addEventListener("mouseleave", this.onPointerLeave)

    this.onVisibility = () => {
      if (document.hidden) this.gsap.globalTimeline.pause()
      else this.gsap.globalTimeline.resume()
    }
    document.addEventListener("visibilitychange", this.onVisibility)
  }

  aim(x, y) {
    if (this.disposed || !this.setters) return

    for (const s of this.setters) {
      s.x(x * 78 * s.depth)
      s.y(y * 54 * s.depth)
      s.rotationY(x * 26 * s.depth)
      s.rotationX(-y * 20 * s.depth)
    }
  }

  // The ambient loop, so the layer is alive before anybody moves a mouse. Each
  // mark wanders on its own path and its own clock; identical tweens would
  // have ten marks rising and falling in unison.
  driftChip(chip, depth) {
    if (!chip) return

    const span = 22 + depth * 26
    const time = parseFloat(chip.style.getPropertyValue("--chip-dur")) || 14
    const delay = parseFloat(chip.style.getPropertyValue("--chip-delay")) || 0
    const tilt = parseFloat(chip.style.getPropertyValue("--chip-tilt")) || 0

    this.gsap.set(chip, { rotation: tilt })

    const loop = this.gsap.timeline({ repeat: -1, delay: Math.abs(delay) % time })
    loop
      .to(chip, { x: span * 0.8, y: -span, rotation: tilt + 9, duration: time * 0.25, ease: "sine.inOut" })
      .to(chip, { x: -span * 0.45, y: -span * 1.7, rotation: tilt - 7, duration: time * 0.25, ease: "sine.inOut" })
      .to(chip, { x: -span, y: -span * 0.8, rotation: tilt + 5, duration: time * 0.25, ease: "sine.inOut" })
      .to(chip, { x: 0, y: 0, rotation: tilt, duration: time * 0.25, ease: "sine.inOut" })

    this.tweens.push(loop)
  }

  disconnect() {
    this.disposed = true

    if (this.onPointerMove) window.removeEventListener("pointermove", this.onPointerMove)
    if (this.onPointerLeave) document.removeEventListener("mouseleave", this.onPointerLeave)
    if (this.onVisibility) document.removeEventListener("visibilitychange", this.onVisibility)

    // Turbo mounts this layer again on the next auth screen, so the old
    // timelines have to go or they keep ticking against detached nodes.
    this.tweens.forEach((t) => t.kill())
    this.tweens = []
    if (this.gsap && this.hasMarkTarget) this.gsap.killTweensOf(this.markTargets)
    this.setters = null
  }
}
