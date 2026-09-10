import { Controller } from "@hotwired/stimulus"

// Mounts the sign-in panel's WebGL scene.
//
// This controller stays deliberately small and cheap, because Stimulus eager
// loads every controller on every page. The scene -- and with it three.js and
// GSAP, around 750KB -- sits behind a dynamic import that only runs once we
// know the panel is really on screen. A phone signing in never downloads any
// of it, and neither does anybody who has asked for less motion.
export default class extends Controller {
  static targets = ["canvas"]

  connect() {
    this.disposed = false
    this.booted = false
    this.running = false
    this.scene = null
    this.timeline = null

    this.motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
    // The panel is `lg:flex`, so below this it is display:none and there is
    // nothing to draw. Matching the breakpoint here means the bytes are never
    // requested rather than requested and thrown away.
    this.widthQuery = window.matchMedia("(min-width: 1024px)")

    // A tablet turned to landscape crosses the breakpoint after connect, so
    // the panel appears and should then get its scene.
    this.onWidthChange = () => this.boot()
    this.widthQuery.addEventListener("change", this.onWidthChange)

    this.boot()
  }

  async boot() {
    if (this.booted || this.disposed) return
    if (!this.widthQuery.matches || !this.hasCanvasTarget) return
    this.booted = true

    let createBroadcastScene
    try {
      ;({ createBroadcastScene } = await import("prachar/broadcast_scene"))
      this.gsap = (await import("gsap")).gsap
    } catch {
      // A blocked or failed fetch leaves the panel's CSS gradient in place,
      // which is a finished design on its own. Nothing to tell the user.
      return
    }

    // Turbo may have torn the panel down while the imports were in flight.
    if (this.disposed) return

    const reducedMotion = this.motionQuery.matches
    this.scene = createBroadcastScene(this.canvasTarget, { reducedMotion })
    if (!this.scene) return

    this.scene.resize()

    this.onResize = () => {
      this.scene.resize()
      // While paused -- offscreen, hidden tab, or reduced motion -- nothing is
      // drawing, so a resize would otherwise leave a stretched last frame.
      if (!this.running) this.scene.render()
    }
    this.resizeObserver = new ResizeObserver(this.onResize)
    this.resizeObserver.observe(this.element)

    if (reducedMotion) {
      // One composed frame: the same picture, holding still.
      this.scene.render()
      return
    }

    this.timeline = this.scene.intro()

    this.onTick = (_time, deltaMs) => {
      // Clamp: returning to a backgrounded tab otherwise delivers one enormous
      // delta and every signal jumps across the screen at once.
      this.scene.advance(Math.min(deltaMs / 1000, 0.05))
      this.scene.render()
    }

    this.onPointerMove = (event) => {
      const bounds = this.element.getBoundingClientRect()
      const x = ((event.clientX - bounds.left) / bounds.width) * 2 - 1
      const y = ((event.clientY - bounds.top) / bounds.height) * 2 - 1
      this.scene.setPointer(x, -y)
    }
    this.element.addEventListener("pointermove", this.onPointerMove, { passive: true })

    this.onVisibility = () => (document.hidden ? this.pause() : this.resume())
    document.addEventListener("visibilitychange", this.onVisibility)

    // Scrolled past, or on a tab nobody is looking at, this should not be
    // burning a GPU -- especially on the laptops small businesses actually use.
    this.intersectionObserver = new IntersectionObserver(
      ([entry]) => (entry.isIntersecting ? this.resume() : this.pause()),
      { threshold: 0.05 }
    )
    this.intersectionObserver.observe(this.element)
  }

  resume() {
    if (this.disposed || this.running || !this.scene || !this.onTick) return
    if (document.hidden) return
    this.running = true
    // GSAP's ticker drives rendering so tweens and frames share one rAF and
    // one clock. Two loops would drift apart and judder against each other.
    this.gsap.ticker.add(this.onTick)
    this.timeline?.play()
  }

  pause() {
    if (!this.running) return
    this.running = false
    this.gsap?.ticker.remove(this.onTick)
    this.timeline?.pause()
  }

  disconnect() {
    this.disposed = true
    this.pause()

    this.widthQuery?.removeEventListener("change", this.onWidthChange)
    this.resizeObserver?.disconnect()
    this.intersectionObserver?.disconnect()
    if (this.onPointerMove) this.element.removeEventListener("pointermove", this.onPointerMove)
    if (this.onVisibility) document.removeEventListener("visibilitychange", this.onVisibility)

    this.timeline?.kill()
    this.scene?.dispose()
    this.scene = null
  }
}
