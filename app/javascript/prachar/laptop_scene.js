// The sign-in laptop.
//
// A laptop is built from primitives, turns in from a three-quarter view, and
// opens its lid to reveal the login form on the screen.
//
// The form is REAL HTML, not a texture. three's CSS3DRenderer transforms DOM
// elements with the same camera matrix the WebGL layer uses, so the form can
// be parented to the lid and swing open with it while remaining a live form:
// password managers fill it, tab moves through it, screen readers read it.
// Painting it into a canvas would look identical and be unusable.
//
// Two renderers are stacked: WebGL underneath draws the laptop, CSS3D on top
// draws the screen's contents. CSS3D cannot be occluded by WebGL geometry, so
// the screen element stays hidden until the lid is open enough that nothing
// should be in front of it.
//
// What makes it read as a real object, in order of how much each contributes:
//   1. an environment map -- metal with nothing to reflect renders flat and
//      dead, and no amount of light fixes it
//   2. filmic tone mapping, so highlights roll off instead of clipping white
//   3. a contact shadow, which is what puts it on a surface rather than in
//      mid-air
//   4. a three-quarter angle and a lid past vertical: a laptop square-on at
//      exactly 90 degrees looks like a diagram of a laptop

import * as THREE from "three"
import { CSS3DRenderer, CSS3DObject } from "css3d-renderer"
import { gsap } from "gsap"

const LAVENDER = "#CEB5D4"
const AZURE = "#4E7AB1"
const SKY = "#7D9FC0"
const SPACE_CADET = "#102B53"

const BASE_W = 5.0
const BASE_D = 3.45
const BASE_H = 0.135
const LID_W = 5.0
const LID_H = 3.25
const LID_T = 0.085
// Smaller than the lid on purpose: the dark border left around it is the
// bezel, and without a visible bezel the form reads as a sticker on the lid
// rather than a screen set into it.
const SCREEN_W = 4.35
const SCREEN_H = 2.7
// The screen's virtual resolution. LOWER is BIGGER: fewer virtual pixels
// across the same world width means every rem of form is drawn larger.
const SCREEN_PX_W = 760
const SCREEN_SCALE = SCREEN_W / SCREEN_PX_W

const LID_CLOSED = Math.PI / 2
// Past vertical, the way a real hinge rests. Exactly 90 degrees is the tell
// that something was modelled rather than observed.
const LID_OPEN = -0.22

// Turned hard for the reveal, then settled to something you can comfortably
// read a password field on. The drama belongs in the animation; the resting
// pose has to be usable.
const TURN_START = -0.85
const TURN_REST = -0.20

const BOKEH_COUNT = 20

function roundedRect(width, height, radius) {
  const shape = new THREE.Shape()
  const w = width / 2
  const h = height / 2
  const r = Math.min(radius, w, h)
  shape.moveTo(-w + r, -h)
  shape.lineTo(w - r, -h)
  shape.quadraticCurveTo(w, -h, w, -h + r)
  shape.lineTo(w, h - r)
  shape.quadraticCurveTo(w, h, w - r, h)
  shape.lineTo(-w + r, h)
  shape.quadraticCurveTo(-w, h, -w, h - r)
  shape.lineTo(-w, -h + r)
  shape.quadraticCurveTo(-w, -h, -w + r, -h)
  return shape
}

// A slab with rounded corners and a bevelled edge. The bevel is the whole
// trick: it gives the silhouette a thin bright line where it catches the
// environment, which is what aluminium does and what a plain box cannot.
function slab(width, height, thickness, radius, bevel = 0.01) {
  const geometry = new THREE.ExtrudeGeometry(roundedRect(width, height, radius), {
    depth: thickness,
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel,
    bevelSegments: 2,
    curveSegments: 12
  })
  geometry.translate(0, 0, -thickness / 2)
  geometry.computeVertexNormals()
  return geometry
}

// A studio, painted into a canvas and convolved into an environment map.
//
// Cheaper than shipping an HDRI and, more usefully, tinted to the sign-in
// palette so the laptop reflects the room it is actually standing in. The
// bright ellipses become the specular streaks that slide across the shell as
// it turns -- they are doing the work that makes it look machined.
function studioEnvironment(renderer) {
  const canvas = document.createElement("canvas")
  canvas.width = 512
  canvas.height = 256
  const ctx = canvas.getContext("2d")

  const sky = ctx.createLinearGradient(0, 0, 0, 256)
  sky.addColorStop(0, "#E8EEF9")
  sky.addColorStop(0.34, SKY)
  sky.addColorStop(0.52, "#2C4E7C")
  sky.addColorStop(0.72, SPACE_CADET)
  sky.addColorStop(1, "#050C18")
  ctx.fillStyle = sky
  ctx.fillRect(0, 0, 512, 256)

  const card = (x, y, w, h, alpha) => {
    const g = ctx.createRadialGradient(x, y, 0, x, y, Math.max(w, h))
    g.addColorStop(0, `rgba(255,255,255,${alpha})`)
    g.addColorStop(1, "rgba(255,255,255,0)")
    ctx.fillStyle = g
    ctx.beginPath()
    ctx.ellipse(x, y, w, h, 0, 0, Math.PI * 2)
    ctx.fill()
  }
  card(120, 54, 130, 46, 0.95) // key light card
  card(360, 40, 96, 34, 0.7)
  card(268, 96, 60, 22, 0.45)

  const tint = ctx.createRadialGradient(430, 150, 0, 430, 150, 120)
  tint.addColorStop(0, "rgba(206,181,212,0.55)") // lavender bounce
  tint.addColorStop(1, "rgba(206,181,212,0)")
  ctx.fillStyle = tint
  ctx.fillRect(310, 60, 220, 180)

  const texture = new THREE.CanvasTexture(canvas)
  texture.mapping = THREE.EquirectangularReflectionMapping
  texture.colorSpace = THREE.SRGBColorSpace

  const pmrem = new THREE.PMREMGenerator(renderer)
  const environment = pmrem.fromEquirectangular(texture).texture
  pmrem.dispose()
  texture.dispose()
  return environment
}

const BOKEH_VERT = /* glsl */ `
  attribute float aSize;
  attribute float aSeed;
  attribute vec3  aColor;
  uniform float uTime;
  uniform float uReveal;
  uniform float uPixelRatio;
  varying vec3  vColor;
  varying float vAlpha;

  void main() {
    vColor = aColor;
    vec3 pos = position;
    // Sine only, no net drift: orbs float in place instead of slowly leaving.
    pos.x += sin(uTime * (0.05 + aSeed * 0.08) + aSeed * 41.0) * 2.2;
    pos.y += sin(uTime * (0.04 + aSeed * 0.06) + aSeed * 19.0) * 1.6;

    vec4  mv   = modelViewMatrix * vec4(pos, 1.0);
    float dist = max(0.001, -mv.z);
    float breathe = 0.7 + 0.3 * sin(uTime * (0.22 + aSeed * 0.35) + aSeed * 88.0);

    // Clamped: drivers cap gl_PointSize, and an orb that hits the cap turns
    // into a hard-edged square.
    gl_PointSize = min(aSize * uPixelRatio * (150.0 / dist), 250.0);
    vAlpha = uReveal * breathe * 0.12;
    gl_Position = projectionMatrix * mv;
  }
`

const BOKEH_FRAG = /* glsl */ `
  varying vec3  vColor;
  varying float vAlpha;
  void main() {
    vec2  uv = gl_PointCoord - 0.5;
    float d  = length(uv);
    if (d > 0.5) discard;
    // Wide feathered edge is what reads as out of focus.
    float falloff = smoothstep(0.5, 0.08, d);
    gl_FragColor = vec4(vColor, falloff * falloff * vAlpha);
  }
`

export function createLaptopScene(canvas, screenElement, { reducedMotion = false, mountScreen = true } = {}) {
  let renderer
  try {
    renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true,
      antialias: true,
      powerPreference: "high-performance"
    })
  } catch {
    return null
  }

  const dpr = Math.min(window.devicePixelRatio || 1, 2)
  renderer.setPixelRatio(dpr)
  renderer.setClearAlpha(0)
  // Filmic response. Without it the specular highlights on the shell clip to
  // flat white and the whole thing looks like plastic.
  renderer.toneMapping = THREE.ACESFilmicToneMapping
  renderer.toneMappingExposure = 1.08
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap

  const scene = new THREE.Scene()
  scene.environment = studioEnvironment(renderer)

  const camera = new THREE.PerspectiveCamera(34, 1, 0.1, 100)
  camera.position.set(0, reducedMotion ? 2.5 : 2.35, reducedMotion ? 8.6 : 9.6)

  // ── CSS3D layer ──────────────────────────────────────────────────────────
  const cssRenderer = new CSS3DRenderer()
  const cssElement = cssRenderer.domElement
  cssElement.style.position = "absolute"
  cssElement.style.inset = "0"
  cssElement.style.pointerEvents = "none"
  canvas.parentElement.appendChild(cssElement)

  // ── Lights ───────────────────────────────────────────────────────────────
  // The environment does most of the lighting; these shape it.
  scene.add(new THREE.AmbientLight(0x9fb4d0, 0.35))

  const key = new THREE.DirectionalLight(0xffffff, 2.4)
  key.position.set(-4.2, 6.4, 5.2)
  key.castShadow = true
  key.shadow.mapSize.set(1024, 1024)
  key.shadow.camera.left = -5
  key.shadow.camera.right = 5
  key.shadow.camera.top = 5
  key.shadow.camera.bottom = -5
  key.shadow.camera.near = 1
  key.shadow.camera.far = 20
  // Without this the bevels self-shadow into dark speckle.
  key.shadow.bias = -0.0009
  key.shadow.radius = 3
  scene.add(key)

  // Stronger now the shell is grey: on graphite this edge light is where the
  // palette's lavender actually lives.
  const rim = new THREE.DirectionalLight(LAVENDER, 2.1)
  rim.position.set(5.5, 2.2, -4.5)
  scene.add(rim)

  // Light spilling off the screen onto the keyboard. Ramps up with the "power
  // on" beat, and is most of why the open laptop reads as lit from within.
  const screenLight = new THREE.PointLight(LAVENDER, 0, 7, 2)
  screenLight.position.set(0, 1.5, 1.2)
  scene.add(screenLight)

  // ── Ground ───────────────────────────────────────────────────────────────
  // Two circles: a glossy dark disc that catches a sheen of the environment
  // (the "polished table" the laptop stands on), and a ShadowMaterial circle
  // over it carrying the contact shadow. Circles rather than planes so both
  // fade out with the surface instead of ending on a straight edge.
  const table = new THREE.Mesh(
    new THREE.CircleGeometry(11, 48),
    new THREE.MeshStandardMaterial({
      color: 0x0a1220,
      metalness: 0.55,
      roughness: 0.32,
      envMapIntensity: 0.5,
      transparent: true,
      opacity: 0.7
    })
  )
  table.rotation.x = -Math.PI / 2
  table.position.y = -0.002
  scene.add(table)

  const ground = new THREE.Mesh(
    new THREE.CircleGeometry(11, 48),
    new THREE.ShadowMaterial({ opacity: 0.5 })
  )
  ground.rotation.x = -Math.PI / 2
  ground.receiveShadow = true
  scene.add(ground)

  // ── Laptop ───────────────────────────────────────────────────────────────
  const laptop = new THREE.Group()
  laptop.rotation.y = reducedMotion ? TURN_REST : TURN_START
  scene.add(laptop)

  // Near-grey graphite, not blue. Aluminium is essentially colourless; the
  // blue in the frame should arrive from the environment and the rim light,
  // the way a grey laptop in a blue room actually looks. Painting the shell
  // navy was what made it read as moulded plastic.
  const shell = new THREE.MeshStandardMaterial({
    color: 0x2b333d,
    metalness: 0.92,
    roughness: 0.3,
    envMapIntensity: 1.45
  })
  const shellDark = new THREE.MeshStandardMaterial({
    color: 0x1a2029,
    metalness: 0.85,
    roughness: 0.42,
    envMapIntensity: 1.0
  })
  const matte = new THREE.MeshStandardMaterial({
    color: 0x0c1016,
    metalness: 0.3,
    roughness: 0.62,
    envMapIntensity: 0.55
  })
  // The bezel is glass, not felt: glossy near-black with enough environment
  // response to catch a faint streak of the room.
  const glass = new THREE.MeshStandardMaterial({
    color: 0x080c12,
    metalness: 0.45,
    roughness: 0.2,
    envMapIntensity: 1.1
  })

  const base = new THREE.Mesh(slab(BASE_W, BASE_D, BASE_H, 0.18, 0.012), shell)
  base.rotation.x = -Math.PI / 2
  base.position.y = BASE_H / 2
  base.castShadow = true
  laptop.add(base)

  // A darker sliver under the base reads as the machined underside and stops
  // the body looking like a single flat wafer.
  const underside = new THREE.Mesh(slab(BASE_W - 0.06, BASE_D - 0.06, 0.03, 0.16, 0.006), shellDark)
  underside.rotation.x = -Math.PI / 2
  underside.position.y = 0.012
  laptop.add(underside)

  const well = new THREE.Mesh(slab(BASE_W - 0.55, BASE_D - 1.35, 0.02, 0.09, 0.005), matte)
  well.rotation.x = -Math.PI / 2
  well.position.set(0, BASE_H + 0.002, -0.44)
  laptop.add(well)

  // The keyboard, still one InstancedMesh (one draw call), but laid out like
  // a keyboard instead of a grid of tiles: a shallow function row, tight key
  // pitch, and a spacebar. The uniform grid was the loudest single tell that
  // this laptop had never been typed on. Cell values are keycap widths in
  // key-units; 0 marks the spacebar's span.
  const KEY_LAYOUT = [
    { z: -1.02, h: 0.55, cells: Array(14).fill(1) },              // fn row
    { z: -0.8, h: 1, cells: Array(14).fill(1) },
    { z: -0.575, h: 1, cells: [1.4, ...Array(12).fill(1), 1.4] },
    { z: -0.35, h: 1, cells: [1.7, ...Array(11).fill(1), 1.7] },
    { z: -0.125, h: 1, cells: [2.1, ...Array(10).fill(1), 2.1] },
    { z: 0.1, h: 1, cells: [1, 1, 1.2, 0, 1.2, 1, 1, 1] }        // 0 = spacebar
  ]
  const KEY_UNIT = 0.258
  const SPACEBAR_UNITS = 4.6
  const keyCount = KEY_LAYOUT.reduce((n, row) => n + row.cells.length, 0)
  const keys = new THREE.InstancedMesh(
    new THREE.BoxGeometry(0.225, 0.024, 0.19),
    new THREE.MeshStandardMaterial({
      // Near-black caps on a graphite deck -- dark keys are what make the
      // deck read as machined rather than printed.
      color: 0x14181f,
      metalness: 0.2,
      roughness: 0.55,
      envMapIntensity: 0.5
    }),
    keyCount
  )
  const dummy = new THREE.Object3D()
  let k = 0
  for (const row of KEY_LAYOUT) {
    const units = row.cells.map((c) => (c === 0 ? SPACEBAR_UNITS : c))
    const total = units.reduce((a, b) => a + b, 0) * KEY_UNIT
    let x = -total / 2
    row.cells.forEach((cell, i) => {
      const w = units[i] * KEY_UNIT
      dummy.position.set(x + w / 2, BASE_H + 0.016, row.z)
      dummy.scale.set(units[i] * (cell === 0 ? 0.985 : 0.92), 1, row.h)
      dummy.updateMatrix()
      keys.setMatrixAt(k++, dummy.matrix)
      x += w
    })
  }
  keys.instanceMatrix.needsUpdate = true
  laptop.add(keys)

  const trackpad = new THREE.Mesh(slab(1.6, 1.0, 0.01, 0.07, 0.004), shellDark)
  trackpad.rotation.x = -Math.PI / 2
  trackpad.position.set(0, BASE_H + 0.005, 1.05)
  laptop.add(trackpad)

  // Hinge barrel, visible in the gap between base and lid at this angle.
  const hinge = new THREE.Mesh(
    new THREE.CylinderGeometry(0.055, 0.055, BASE_W - 1.4, 16),
    matte
  )
  hinge.rotation.z = Math.PI / 2
  hinge.position.set(0, BASE_H + 0.02, -BASE_D / 2 + 0.06)
  laptop.add(hinge)

  // Lid, on a pivot at the hinge so rotation.x is literally the hinge angle.
  const lidPivot = new THREE.Group()
  lidPivot.position.set(0, BASE_H, -BASE_D / 2)
  lidPivot.rotation.x = reducedMotion ? LID_OPEN : LID_CLOSED
  laptop.add(lidPivot)

  const lid = new THREE.Mesh(slab(LID_W, LID_H, LID_T, 0.18, 0.01), shell)
  lid.position.set(0, LID_H / 2, 0)
  lid.castShadow = true
  lidPivot.add(lid)

  // Bezel: the glossy dark frame the screen sits in. Missing this is the
  // single biggest giveaway that a laptop was modelled from memory.
  const bezel = new THREE.Mesh(new THREE.PlaneGeometry(LID_W - 0.14, LID_H - 0.14), glass)
  bezel.position.set(0, LID_H / 2, LID_T / 2 + 0.003)
  lidPivot.add(bezel)

  const cameraDot = new THREE.Mesh(
    new THREE.CircleGeometry(0.022, 16),
    new THREE.MeshStandardMaterial({ color: 0x05101f, metalness: 0.1, roughness: 0.3 })
  )
  cameraDot.position.set(0, LID_H - 0.14, LID_T / 2 + 0.006)
  lidPivot.add(cameraDot)

  const screenMaterial = new THREE.MeshStandardMaterial({
    color: 0x060f1f,
    metalness: 0.15,
    roughness: 0.34,
    emissive: new THREE.Color(AZURE),
    emissiveIntensity: 0
  })
  const screen = new THREE.Mesh(new THREE.PlaneGeometry(SCREEN_W, SCREEN_H), screenMaterial)
  screen.position.set(0, LID_H / 2 + 0.05, LID_T / 2 + 0.008)
  lidPivot.add(screen)

  // The live form, parented to the lid so it opens with it. In backdrop mode
  // (reduced motion, or after the hand-off) the form lives in normal flow
  // instead and the laptop is scenery, so nothing is mounted.
  if (mountScreen) {
    screenElement.style.width = `${SCREEN_PX_W}px`
    screenElement.style.height = `${Math.round(SCREEN_PX_W * (SCREEN_H / SCREEN_W))}px`
    const screenObject = new CSS3DObject(screenElement)
    screenObject.position.copy(screen.position)
    screenObject.position.z += 0.012
    screenObject.scale.setScalar(SCREEN_SCALE)
    lidPivot.add(screenObject)
  }

  // ── Bokeh ────────────────────────────────────────────────────────────────
  const bokehPositions = new Float32Array(BOKEH_COUNT * 3)
  const bokehColors = new Float32Array(BOKEH_COUNT * 3)
  const bokehSizes = new Float32Array(BOKEH_COUNT)
  const bokehSeeds = new Float32Array(BOKEH_COUNT)
  const scratch = new THREE.Color()

  for (let i = 0; i < BOKEH_COUNT; i++) {
    bokehPositions.set(
      [(Math.random() * 2 - 1) * 22, (Math.random() * 2 - 1) * 13, -9 - Math.random() * 13],
      i * 3
    )
    const t = Math.random()
    scratch.set(t < 0.4 ? SKY : t < 0.72 ? AZURE : t < 0.92 ? LAVENDER : SPACE_CADET)
    bokehColors.set([scratch.r, scratch.g, scratch.b], i * 3)
    bokehSizes[i] = 7 + Math.random() * 12
    bokehSeeds[i] = Math.random()
  }

  const bokehGeometry = new THREE.BufferGeometry()
  bokehGeometry.setAttribute("position", new THREE.BufferAttribute(bokehPositions, 3))
  bokehGeometry.setAttribute("aColor", new THREE.BufferAttribute(bokehColors, 3))
  bokehGeometry.setAttribute("aSize", new THREE.BufferAttribute(bokehSizes, 1))
  bokehGeometry.setAttribute("aSeed", new THREE.BufferAttribute(bokehSeeds, 1))

  const bokehUniforms = {
    uTime: { value: 0 },
    uReveal: { value: reducedMotion ? 1 : 0 },
    uPixelRatio: { value: dpr }
  }
  const bokeh = new THREE.Points(
    bokehGeometry,
    new THREE.ShaderMaterial({
      uniforms: bokehUniforms,
      vertexShader: BOKEH_VERT,
      fragmentShader: BOKEH_FRAG,
      transparent: true,
      depthWrite: false,
      depthTest: false,
      blending: THREE.AdditiveBlending
    })
  )
  bokeh.renderOrder = -2
  scene.add(bokeh)

  // ── State ────────────────────────────────────────────────────────────────
  if (reducedMotion) {
    screenLight.intensity = 1.8
    screenMaterial.emissiveIntensity = 0.4
  } else {
    laptop.position.y = -0.5
    laptop.scale.setScalar(0.93)
  }
  if (mountScreen) {
    screenElement.style.opacity = reducedMotion ? "1" : "0"
    screenElement.style.pointerEvents = reducedMotion ? "auto" : "none"
  }

  let elapsed = 0
  const pointer = { x: 0, y: 0 }
  const eased = { x: 0, y: 0 }
  const state = { parallax: reducedMotion ? 0 : 1, turn: laptop.rotation.y }

  function advance(delta) {
    elapsed += delta
    bokehUniforms.uTime.value = elapsed

    // Parallax fades out as the intro ends: a form that drifts under the
    // pointer while somebody is trying to click into it is a nuisance, and
    // every CSS3D transform change re-rasterises the element.
    eased.x += (pointer.x * state.parallax - eased.x) * Math.min(1, delta * 1.8)
    eased.y += (pointer.y * state.parallax - eased.y) * Math.min(1, delta * 1.8)
    laptop.rotation.y = state.turn + eased.x * 0.07
    laptop.rotation.x = -eased.y * 0.03
  }

  function render() {
    renderer.render(scene, camera)
    cssRenderer.render(scene, camera)
  }

  function resize() {
    const width = canvas.clientWidth || 1
    const height = canvas.clientHeight || 1
    renderer.setSize(width, height, false)
    cssRenderer.setSize(width, height)
    camera.aspect = width / height
    // Widen the field of view on short windows, where a fixed one would crop
    // the lid off the top.
    camera.fov = width / height < 1.55 ? 42 : 34
    camera.updateProjectionMatrix()
    camera.lookAt(0, 1.45, 0)
  }

  function setPointer(x, y) {
    pointer.x = x
    pointer.y = y
  }

  function intro({ onComplete } = {}) {
    const timeline = gsap.timeline({
      paused: true,
      defaults: { ease: "power2.out" },
      onComplete: () => {
        screenElement.style.pointerEvents = "auto"
        gsap.to(state, { parallax: 0, duration: 0.8 })
        onComplete?.()
      }
    })

    // Slowed on request: the owner wants this watched, not endured, and the
    // skip-on-any-input path covers whoever disagrees. ~4.5s end to end.
    timeline
      // Dolly in. Most of the "zoom" is here rather than in a scale, so the
      // perspective changes with it and the move reads as a camera.
      .to(camera.position, { z: 6.1, duration: 4.2, ease: "power2.inOut" }, 0)
      .to(laptop.position, { y: 0, duration: 2.2, ease: "power3.out" }, 0.15)
      .to(laptop.scale, { x: 1, y: 1, z: 1, duration: 2.2, ease: "power3.out" }, 0.15)
      // The turn: hard three-quarter to a gentler resting angle, so the
      // highlights sweep across the shell as it settles.
      .to(state, { turn: TURN_REST, duration: 3.8, ease: "power2.inOut" }, 0.2)
      .to(bokehUniforms.uReveal, { value: 1, duration: 2.4 }, 0)
      // The hinge. back.out overshoots a few degrees and settles, which is
      // what a weighted lid actually does.
      .to(lidPivot.rotation, { x: LID_OPEN, duration: 2.1, ease: "back.out(1.1)" }, 1.2)
      .to(screenLight, { intensity: 1.8, duration: 1.0 }, 2.6)
      .to(screenMaterial, { emissiveIntensity: 0.4, duration: 1.0 }, 2.6)
      .to(screenElement, { opacity: 1, duration: 0.8 }, 2.9)

    return timeline
  }

  // After the intro: the form leaves the screen and the laptop steps back to
  // become scenery. Ending on a flat, full-size card is what keeps the page
  // readable and calm once the show is over -- the animation is the entrance,
  // not the furniture.
  function handoff() {
    const timeline = gsap.timeline({ defaults: { ease: "power2.inOut" } })
    timeline
      .to(screenElement, { opacity: 0, duration: 0.4, ease: "power1.out" }, 0)
      .to(camera.position, { z: 8.6, y: 2.5, duration: 1.2 }, 0.05)
      .to(laptop.position, { y: -0.35, duration: 1.2 }, 0.05)
      .to(laptop.scale, { x: 0.9, y: 0.9, z: 0.9, duration: 1.2 }, 0.05)
      .to(state, { turn: TURN_REST - 0.06, duration: 1.2 }, 0.05)
      .to(screenLight, { intensity: 1.1, duration: 1.2 }, 0.05)
    return timeline
  }

  function dispose() {
    scene.environment?.dispose()
    scene.traverse((object) => {
      if (object.geometry) object.geometry.dispose()
      if (object.material) {
        if (Array.isArray(object.material)) object.material.forEach((m) => m.dispose())
        else object.material.dispose()
      }
    })
    renderer.dispose()
    renderer.forceContextLoss?.()
    // Detach the CSS3D layer, not the form: the controller puts the form back
    // where the server rendered it.
    cssElement.remove()
  }

  return { advance, render, resize, setPointer, intro, handoff, dispose }
}
