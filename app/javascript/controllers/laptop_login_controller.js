import { Controller } from "@hotwired/stimulus"

// Drives the sign-in laptop.
//
// The order of operations here is a safety property, not a style choice. The
// form renders as an ordinary centred card and is fully usable before any of
// this runs. Only once three.js has loaded AND a WebGL context exists is the
// form moved onto the 3D screen -- and after the intro it is moved straight
// back, because the animation is the entrance, not the furniture. Every
// failure path leaves a working login page rather than a locked door.
//
// Life cycle:  plain card -> (scene loads) -> form on the laptop screen ->
// lid opens -> hand-off: form returns to normal flow as the same plain card,
// laptop retires to a soft backdrop. Reduced motion goes directly to the
// final state.
export default class extends Controller {
  static targets = ["canvas", "screen", "focus"]

  connect() {
    this.disposed = false
    this.booted = false
    this.running = false
    this.docked = false
    this.scene = null
    this.timeline = null

    this.motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.widthQuery = window.matchMedia("(min-width: 1024px)")

    this.onWidthChange = () => this.boot()
    this.widthQuery.addEventListener("change", this.onWidthChange)

    this.boot()
  }

  async boot() {
    if (this.booted || this.disposed) return
    if (!this.widthQuery.matches) return
    if (!this.hasCanvasTarget || !this.hasScreenTarget) return
    this.booted = true

    let createLaptopScene
    try {
      ;({ createLaptopScene } = await import("prachar/laptop_scene"))
      this.gsap = (await import("gsap")).gsap
    } catch {
      return // form stays exactly where it is, working
    }
    if (this.disposed) return

    const reducedMotion = this.motionQuery.matches

    // Reduced motion: no mounting, no timeline. The laptop is rendered once,
    // open, as a still backdrop behind the ordinary card.
    if (reducedMotion) {
      this.scene = createLaptopScene(this.canvasTarget, this.screenTarget, {
        reducedMotion: true,
        mountScreen: false
      })
      if (!this.scene) return
      this.element.classList.add("is-docked")
      this.scene.resize()
      this.scene.render()
      this.watchResize(() => {
        this.scene.resize()
        this.scene.render()
      })
      return
    }

    // Remembered so the element can be put back; CSS3D reparents it into its
    // own layer and would otherwise strand it there across a Turbo visit.
    this.screenHome = this.screenTarget.parentElement
    this.screenNext = this.screenTarget.nextElementSibling

    this.scene = createLaptopScene(this.canvasTarget, this.screenTarget, { reducedMotion: false })
    if (!this.scene) {
      this.screenHome = null
      return
    }

    this.element.classList.add("is-mounted")
    this.scene.resize()
    // One frame now, before GSAP's first tick: without it, a slow connection
    // shows an empty room until the ticker starts.
    this.scene.render()

    this.watchResize(() => {
      this.scene.resize()
      if (!this.running) this.scene.render()
    })

    this.onTick = (_time, deltaMs) => {
      this.scene.advance(Math.min(deltaMs / 1000, 0.05))
      this.scene.render()
    }

    this.onPointerMove = (event) => {
      const bounds = this.element.getBoundingClientRect()
      this.scene.setPointer(
        ((event.clientX - bounds.left) / bounds.width) * 2 - 1,
        -(((event.clientY - bounds.top) / bounds.height) * 2 - 1)
      )
    }
    this.element.addEventListener("pointermove", this.onPointerMove, { passive: true })

    this.onVisibility = () => (document.hidden ? this.pause() : this.resume())
    document.addEventListener("visibilitychange", this.onVisibility)

    this.timeline = this.scene.intro({ onComplete: () => this.dock() })

    // Anybody who came to log in rather than to watch a laptop can say so:
    // any key or click jumps to the end state.
    this.onSkip = (event) => {
      if (event.type === "keydown" && (event.metaKey || event.ctrlKey || event.altKey)) return
      this.skip()
    }
    document.addEventListener("keydown", this.onSkip)
    this.element.addEventListener("pointerdown", this.onSkip)

    this.resume()
  }

  watchResize(handler) {
    this.onResize = handler
    this.resizeObserver = new ResizeObserver(handler)
    this.resizeObserver.observe(this.element)
  }

  skip() {
    if (!this.timeline || this.skipped) return
    this.skipped = true
    // progress(1) fires the timeline's onComplete, so the hand-off and focus
    // run through the same path as a natural finish.
    this.timeline.progress(1)
    this.clearSkip()
  }

  // The hand-off: form off the screen, back into normal flow as the plain
  // card; laptop steps back to scenery. Ending flat and full-size is what
  // keeps the page readable once the show is over.
  dock() {
    if (this.docked || this.disposed) return
    this.docked = true
    this.clearSkip()

    const finish = () => {
      if (this.disposed) return
      this.restoreScreen()
      this.element.classList.remove("is-mounted")
      this.element.classList.add("is-docked")
      if (this.hasFocusTarget) {
        try { this.focusTarget.focus({ preventScroll: true }) } catch { /* not focusable */ }
      }
    }

    const handoff = this.scene.handoff()
    // The card reappears in flow as soon as the screen copy has faded, while
    // the laptop is still drifting back behind it.
    handoff.call(finish, [], 0.45)
  }

  restoreScreen() {
    if (!this.screenHome || !this.hasScreenTarget) return
    const el = this.screenTarget
    el.style.width = el.style.height = el.style.opacity = el.style.pointerEvents = ""
    this.screenHome.insertBefore(el, this.screenNext)
    this.screenHome = null
  }

  clearSkip() {
    if (!this.onSkip) return
    document.removeEventListener("keydown", this.onSkip)
    this.element.removeEventListener("pointerdown", this.onSkip)
    this.onSkip = null
  }

  resume() {
    if (this.disposed || this.running || !this.scene || !this.onTick || document.hidden) return
    this.running = true
    this.gsap.ticker.add(this.onTick)
    if (!this.docked) this.timeline?.play()
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
    this.clearSkip()

    this.widthQuery?.removeEventListener("change", this.onWidthChange)
    this.resizeObserver?.disconnect()
    if (this.onPointerMove) this.element.removeEventListener("pointermove", this.onPointerMove)
    if (this.onVisibility) document.removeEventListener("visibilitychange", this.onVisibility)

    this.timeline?.kill()
    this.scene?.dispose()
    this.scene = null

    this.restoreScreen()
    this.element.classList.remove("is-mounted", "is-docked")
  }
}
