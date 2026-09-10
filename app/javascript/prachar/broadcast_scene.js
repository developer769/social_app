// The animation behind the sign-in and sign-up brand panel.
//
// "Prachar" means spreading the word, and that is what the application does:
// a post leaves the workspace, reaches an audience, and engagement comes back.
// The scene is that sentence -- a core that broadcasts, a network that lights
// up as signals land, and returning sparks. It is decoration, so every part of
// it is written to cost as little as possible and to disappear cleanly.
//
// Performance notes, because a login screen must never feel heavy:
//   * three geometries in total -- nodes, links, signals -- each one draw call.
//     Per-node work happens on the GPU through attributes, not in JavaScript.
//   * the only per-frame CPU work is advancing ~48 signals and decaying flares.
//   * GSAP's ticker drives rendering, so the tween clock and the render loop
//     share one rAF rather than fighting over two.
//   * the loop stops when the panel scrolls away or the tab is hidden.

import * as THREE from "three"
import { gsap } from "gsap"

// The sign-in palette (see "ocean" in app/assets/tailwind/application.css).
// Space Cadet is the ground, so it lives in CSS on the panel itself; the
// canvas is transparent and only adds light on top. That way a WebGL failure
// leaves a good-looking gradient rather than a black rectangle.
const LAVENDER = new THREE.Color("#CEB5D4") // pink lavender: the accent
const STEEL = new THREE.Color("#50698D")    // ucla blue
const AZURE = new THREE.Color("#4E7AB1")    // cyan azure
const SKY = new THREE.Color("#7D9FC0")      // air superiority blue
const MIST = new THREE.Color("#E9F0F8")     // near-white blue, for highlights

const NODE_COUNT = 150
const SIGNAL_COUNT = 48
const NEIGHBOUR_LINKS = 90
const BOKEH_COUNT = 24

// Fibonacci sphere: even coverage without the clustering at the poles that
// random spherical coordinates produce.
function fibonacciSphere(i, total) {
  const y = 1 - (i / (total - 1)) * 2
  const radius = Math.sqrt(Math.max(0, 1 - y * y))
  const theta = i * 2.399963229728653 // golden angle
  return new THREE.Vector3(Math.cos(theta) * radius, y, Math.sin(theta) * radius)
}

const NODE_VERT = /* glsl */ `
  attribute float aSize;
  attribute vec3  aColor;
  attribute float aSeed;
  attribute float aFlare;

  uniform float uTime;
  uniform float uReveal;
  uniform float uPixelRatio;

  varying vec3  vColor;
  varying float vAlpha;

  void main() {
    vColor = aColor;

    // Each node emerges from the core on its own beat, so the network builds
    // outward instead of appearing all at once.
    float born = smoothstep(aSeed * 0.55, aSeed * 0.55 + 0.45, uReveal);
    vec3  pos  = position * born;

    vec4  mv   = modelViewMatrix * vec4(pos, 1.0);
    float dist = max(0.001, -mv.z);

    float breathe = 0.82 + 0.18 * sin(uTime * 1.1 + aSeed * 24.0);
    gl_PointSize = aSize * breathe * (1.0 + aFlare * 2.6) * uPixelRatio * (150.0 / dist);

    // Depth fade stands in for a depth-of-field pass: far nodes sit back
    // without costing a second render target.
    vAlpha = born * (0.30 + 0.70 * smoothstep(34.0, 8.0, dist)) * (0.55 + aFlare * 0.9);

    gl_Position = projectionMatrix * mv;
  }
`

const NODE_FRAG = /* glsl */ `
  varying vec3  vColor;
  varying float vAlpha;

  void main() {
    // A round sprite drawn procedurally -- no texture to load or decode.
    vec2  uv = gl_PointCoord - 0.5;
    float d  = length(uv);
    if (d > 0.5) discard;

    float falloff = smoothstep(0.5, 0.0, d);
    float glow    = pow(falloff, 2.6);

    gl_FragColor = vec4(vColor * (0.55 + glow * 1.7), vAlpha * glow);
  }
`

const SIGNAL_VERT = /* glsl */ `
  attribute vec3  aColor;
  attribute float aIntensity;

  uniform float uPixelRatio;

  varying vec3  vColor;
  varying float vIntensity;

  void main() {
    vColor = aColor;
    vIntensity = aIntensity;

    vec4  mv   = modelViewMatrix * vec4(position, 1.0);
    float dist = max(0.001, -mv.z);

    gl_PointSize = 7.0 * aIntensity * uPixelRatio * (150.0 / dist);
    gl_Position  = projectionMatrix * mv;
  }
`

const SIGNAL_FRAG = /* glsl */ `
  varying vec3  vColor;
  varying float vIntensity;

  void main() {
    vec2  uv = gl_PointCoord - 0.5;
    float d  = length(uv);
    if (d > 0.5) discard;

    float falloff = smoothstep(0.5, 0.0, d);
    // Signals run hotter than nodes: a white centre bleeding into their colour
    // is what makes them read as light rather than as coloured dots.
    vec3  hot = mix(vColor, vec3(1.0), pow(falloff, 3.0) * 0.85);

    gl_FragColor = vec4(hot, falloff * vIntensity);
  }
`

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

    // Pure sine wobble, no net drift: bokeh floats in place. A translation
    // would eventually carry every orb off screen in a long session.
    vec3 pos = position;
    pos.x += sin(uTime * (0.05 + aSeed * 0.09) + aSeed * 43.0) * 2.4;
    pos.y += sin(uTime * (0.04 + aSeed * 0.07) + aSeed * 17.0) * 1.8;

    vec4  mv   = modelViewMatrix * vec4(pos, 1.0);
    float dist = max(0.001, -mv.z);

    float breathe = 0.7 + 0.3 * sin(uTime * (0.25 + aSeed * 0.4) + aSeed * 90.0);
    // Clamped: GPUs cap gl_PointSize at driver-specific limits, and an orb
    // that silently hits the cap turns into a hard-edged square. Staying
    // under the common floor keeps them soft everywhere.
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

    // A wide feathered edge is what reads as "out of focus"; a crisp disc at
    // this size would read as confetti instead.
    float falloff = smoothstep(0.5, 0.08, d);
    gl_FragColor = vec4(vColor, falloff * falloff * vAlpha);
  }
`

const CORE_VERT = /* glsl */ `
  varying vec3 vNormal;
  varying vec3 vView;

  void main() {
    vNormal = normalize(normalMatrix * normal);
    vec4 mv = modelViewMatrix * vec4(position, 1.0);
    vView = normalize(-mv.xyz);
    gl_Position = projectionMatrix * mv;
  }
`

const CORE_FRAG = /* glsl */ `
  uniform vec3  uInner;
  uniform vec3  uOuter;
  uniform float uTime;
  uniform float uOpacity;

  varying vec3 vNormal;
  varying vec3 vView;

  void main() {
    // Fresnel: bright at grazing angles, so the shape reads as a lit volume
    // rather than a flat disc, without any lights in the scene.
    float rim  = 1.0 - clamp(dot(normalize(vNormal), normalize(vView)), 0.0, 1.0);
    float edge = pow(rim, 2.2);
    float beat = 0.9 + 0.1 * sin(uTime * 1.6);

    vec3 col = mix(uInner, uOuter, edge) * (0.5 + edge * 1.4) * beat;
    gl_FragColor = vec4(col, (0.18 + edge * 0.9) * uOpacity);
  }
`

const HALO_VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`

const HALO_FRAG = /* glsl */ `
  uniform vec3  uColor;
  uniform float uTime;
  uniform float uOpacity;

  varying vec2 vUv;

  void main() {
    float d = length(vUv - 0.5) * 2.0;
    if (d > 1.0) discard;

    float beat  = 0.88 + 0.12 * sin(uTime * 1.6);
    float inner = pow(1.0 - clamp(d, 0.0, 1.0), 3.0);
    float wide  = pow(1.0 - clamp(d, 0.0, 1.0), 1.3) * 0.35;

    gl_FragColor = vec4(uColor, (inner + wide) * beat * uOpacity);
  }
`

export function createBroadcastScene(canvas, { reducedMotion = false } = {}) {
  let renderer
  try {
    renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true,
      antialias: true,
      powerPreference: "high-performance"
    })
  } catch {
    // No WebGL. The panel's CSS gradient is the fallback and already looks
    // finished, so failing here is silent on purpose.
    return null
  }

  const clampedDpr = Math.min(window.devicePixelRatio || 1, 2)
  renderer.setPixelRatio(clampedDpr)
  renderer.setClearAlpha(0)

  const scene = new THREE.Scene()
  const camera = new THREE.PerspectiveCamera(46, 1, 0.1, 120)
  camera.position.set(0, 0, 30)

  const world = new THREE.Group()
  scene.add(world)

  // ── Nodes ────────────────────────────────────────────────────────────────
  const nodePositions = new Float32Array(NODE_COUNT * 3)
  const nodeColors = new Float32Array(NODE_COUNT * 3)
  const nodeSizes = new Float32Array(NODE_COUNT)
  const nodeSeeds = new Float32Array(NODE_COUNT)
  const nodeFlares = new Float32Array(NODE_COUNT)
  const nodeVectors = []

  const scratch = new THREE.Color()
  for (let i = 0; i < NODE_COUNT; i++) {
    // Radius varies so the shell has thickness and the eye finds depth.
    const radius = 7.5 + Math.pow(Math.random(), 0.7) * 7.5
    const v = fibonacciSphere(i, NODE_COUNT).multiplyScalar(radius)
    v.z *= 0.7 // slightly flattened: more of the network faces the camera
    nodeVectors.push(v)
    nodePositions.set([v.x, v.y, v.z], i * 3)

    const t = Math.random()
    if (t < 0.45) scratch.copy(SKY)
    else if (t < 0.75) scratch.copy(AZURE)
    else if (t < 0.92) scratch.copy(LAVENDER)
    else scratch.copy(MIST)
    nodeColors.set([scratch.r, scratch.g, scratch.b], i * 3)

    nodeSizes[i] = 1.4 + Math.random() * 2.6
    nodeSeeds[i] = Math.random()
  }

  const nodeGeometry = new THREE.BufferGeometry()
  nodeGeometry.setAttribute("position", new THREE.BufferAttribute(nodePositions, 3))
  nodeGeometry.setAttribute("aColor", new THREE.BufferAttribute(nodeColors, 3))
  nodeGeometry.setAttribute("aSize", new THREE.BufferAttribute(nodeSizes, 1))
  nodeGeometry.setAttribute("aSeed", new THREE.BufferAttribute(nodeSeeds, 1))
  nodeGeometry.setAttribute("aFlare", new THREE.BufferAttribute(nodeFlares, 1))

  const nodeUniforms = {
    uTime: { value: 0 },
    uReveal: { value: reducedMotion ? 1 : 0 },
    uPixelRatio: { value: clampedDpr }
  }

  const nodeMaterial = new THREE.ShaderMaterial({
    uniforms: nodeUniforms,
    vertexShader: NODE_VERT,
    fragmentShader: NODE_FRAG,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending
  })
  world.add(new THREE.Points(nodeGeometry, nodeMaterial))

  // ── Links ────────────────────────────────────────────────────────────────
  // Two kinds: spokes from the core (the broadcast paths signals travel), and
  // short neighbour links that make the outer shell read as a network rather
  // than as loose confetti.
  const spokeTargets = []
  for (let i = 0; i < NODE_COUNT; i++) if (Math.random() < 0.42) spokeTargets.push(i)

  const linkPoints = []
  const linkColors = []
  const origin = new THREE.Vector3()

  for (const i of spokeTargets) {
    linkPoints.push(origin.x, origin.y, origin.z, nodeVectors[i].x, nodeVectors[i].y, nodeVectors[i].z)
    linkColors.push(LAVENDER.r * 0.5, LAVENDER.g * 0.5, LAVENDER.b * 0.5, STEEL.r * 0.28, STEEL.g * 0.28, STEEL.b * 0.28)
  }

  for (let n = 0; n < NEIGHBOUR_LINKS; n++) {
    const a = Math.floor(Math.random() * NODE_COUNT)
    let best = -1
    let bestDist = Infinity
    // Sampling a handful of candidates finds a near neighbour without the
    // O(n^2) pass a true nearest-neighbour search would need.
    for (let k = 0; k < 12; k++) {
      const b = Math.floor(Math.random() * NODE_COUNT)
      if (b === a) continue
      const d = nodeVectors[a].distanceToSquared(nodeVectors[b])
      if (d < bestDist) { bestDist = d; best = b }
    }
    if (best < 0 || bestDist > 30) continue
    linkPoints.push(
      nodeVectors[a].x, nodeVectors[a].y, nodeVectors[a].z,
      nodeVectors[best].x, nodeVectors[best].y, nodeVectors[best].z
    )
    linkColors.push(SKY.r * 0.18, SKY.g * 0.18, SKY.b * 0.18, SKY.r * 0.18, SKY.g * 0.18, SKY.b * 0.18)
  }

  const linkGeometry = new THREE.BufferGeometry()
  linkGeometry.setAttribute("position", new THREE.Float32BufferAttribute(linkPoints, 3))
  linkGeometry.setAttribute("color", new THREE.Float32BufferAttribute(linkColors, 3))

  const linkMaterial = new THREE.LineBasicMaterial({
    vertexColors: true,
    transparent: true,
    opacity: reducedMotion ? 0.55 : 0,
    depthWrite: false,
    blending: THREE.AdditiveBlending
  })
  world.add(new THREE.LineSegments(linkGeometry, linkMaterial))

  // ── Bokeh ────────────────────────────────────────────────────────────────
  // The mood of the palette's reference photograph: large defocused orbs
  // hanging behind the network. They reuse the nodes' uniform objects, so the
  // intro reveal and the shared clock drive them for free.
  const bokehPositions = new Float32Array(BOKEH_COUNT * 3)
  const bokehColors = new Float32Array(BOKEH_COUNT * 3)
  const bokehSizes = new Float32Array(BOKEH_COUNT)
  const bokehSeeds = new Float32Array(BOKEH_COUNT)

  for (let i = 0; i < BOKEH_COUNT; i++) {
    bokehPositions.set(
      [(Math.random() * 2 - 1) * 24, (Math.random() * 2 - 1) * 14, -6 - Math.random() * 14],
      i * 3
    )
    const t = Math.random()
    if (t < 0.4) scratch.copy(SKY)
    else if (t < 0.7) scratch.copy(AZURE)
    else if (t < 0.9) scratch.copy(LAVENDER)
    else scratch.copy(STEEL)
    bokehColors.set([scratch.r, scratch.g, scratch.b], i * 3)
    bokehSizes[i] = 7 + Math.random() * 11
    bokehSeeds[i] = Math.random()
  }

  const bokehGeometry = new THREE.BufferGeometry()
  bokehGeometry.setAttribute("position", new THREE.BufferAttribute(bokehPositions, 3))
  bokehGeometry.setAttribute("aColor", new THREE.BufferAttribute(bokehColors, 3))
  bokehGeometry.setAttribute("aSize", new THREE.BufferAttribute(bokehSizes, 1))
  bokehGeometry.setAttribute("aSeed", new THREE.BufferAttribute(bokehSeeds, 1))

  const bokehMaterial = new THREE.ShaderMaterial({
    // The same uniforms OBJECT as the nodes, not a copy: one write to
    // uTime/uReveal per frame reaches both materials.
    uniforms: nodeUniforms,
    vertexShader: BOKEH_VERT,
    fragmentShader: BOKEH_FRAG,
    transparent: true,
    depthWrite: false,
    depthTest: false,
    blending: THREE.AdditiveBlending
  })
  const bokeh = new THREE.Points(bokehGeometry, bokehMaterial)
  bokeh.renderOrder = -2
  // In the scene, not the rotating group: defocused background light does not
  // orbit the subject.
  scene.add(bokeh)

  // ── Core ─────────────────────────────────────────────────────────────────
  const coreUniforms = {
    uInner: { value: AZURE.clone() },
    uOuter: { value: LAVENDER.clone() },
    uTime: { value: 0 },
    uOpacity: { value: reducedMotion ? 1 : 0 }
  }
  const coreMesh = new THREE.Mesh(
    new THREE.IcosahedronGeometry(2.5, 3),
    new THREE.ShaderMaterial({
      uniforms: coreUniforms,
      vertexShader: CORE_VERT,
      fragmentShader: CORE_FRAG,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    })
  )
  if (!reducedMotion) coreMesh.scale.setScalar(0.001)
  world.add(coreMesh)

  const haloUniforms = {
    uColor: { value: LAVENDER.clone() },
    uTime: { value: 0 },
    uOpacity: { value: reducedMotion ? 0.75 : 0 }
  }
  const halo = new THREE.Mesh(
    new THREE.PlaneGeometry(22, 22),
    new THREE.ShaderMaterial({
      uniforms: haloUniforms,
      vertexShader: HALO_VERT,
      fragmentShader: HALO_FRAG,
      transparent: true,
      depthWrite: false,
      depthTest: false,
      blending: THREE.AdditiveBlending
    })
  )
  halo.renderOrder = -1
  // Parented to the scene, not to `world`: it is billboarded by copying the
  // camera's rotation each frame, and a rotating parent would compose with
  // that and tilt it back out of view.
  scene.add(halo)

  // ── Signals ──────────────────────────────────────────────────────────────
  const signalPositions = new Float32Array(SIGNAL_COUNT * 3)
  const signalColors = new Float32Array(SIGNAL_COUNT * 3)
  const signalIntensity = new Float32Array(SIGNAL_COUNT)
  const signals = []

  function launch(signal, stagger) {
    const target = spokeTargets.length
      ? spokeTargets[Math.floor(Math.random() * spokeTargets.length)]
      : Math.floor(Math.random() * NODE_COUNT)
    // A quarter of the traffic runs the other way: engagement coming home is
    // as much a part of the product as publishing is.
    signal.inbound = Math.random() < 0.25
    signal.node = target
    signal.t = stagger ? -Math.random() * 2.4 : -Math.random() * 0.7
    signal.speed = 0.28 + Math.random() * 0.34
    const colour = signal.inbound ? AZURE : LAVENDER
    signalColors.set([colour.r, colour.g, colour.b], signal.index * 3)
  }

  for (let i = 0; i < SIGNAL_COUNT; i++) {
    const signal = { index: i, node: 0, t: 0, speed: 0, inbound: false }
    signals.push(signal)
    launch(signal, true)
  }

  const signalGeometry = new THREE.BufferGeometry()
  signalGeometry.setAttribute("position", new THREE.BufferAttribute(signalPositions, 3))
  signalGeometry.setAttribute("aColor", new THREE.BufferAttribute(signalColors, 3))
  signalGeometry.setAttribute("aIntensity", new THREE.BufferAttribute(signalIntensity, 1))

  const signalUniforms = { uPixelRatio: { value: clampedDpr } }
  const signalMaterial = new THREE.ShaderMaterial({
    uniforms: signalUniforms,
    vertexShader: SIGNAL_VERT,
    fragmentShader: SIGNAL_FRAG,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending
  })
  world.add(new THREE.Points(signalGeometry, signalMaterial))

  // ── Motion ───────────────────────────────────────────────────────────────
  const pointer = { x: 0, y: 0 }
  const eased = { x: 0, y: 0 }
  let elapsed = 0

  function advance(delta) {
    elapsed += delta
    nodeUniforms.uTime.value = elapsed
    coreUniforms.uTime.value = elapsed
    haloUniforms.uTime.value = elapsed

    world.rotation.y += delta * 0.055
    world.rotation.x = Math.sin(elapsed * 0.16) * 0.11
    coreMesh.rotation.y -= delta * 0.22
    coreMesh.rotation.x += delta * 0.1

    // The panel reacts to the pointer, but lazily -- a hard follow feels
    // twitchy next to a form somebody is trying to type into.
    eased.x += (pointer.x - eased.x) * Math.min(1, delta * 2.2)
    eased.y += (pointer.y - eased.y) * Math.min(1, delta * 2.2)
    camera.position.x = eased.x * 3.2
    camera.position.y = eased.y * 2.2
    camera.lookAt(0, 0, 0)

    halo.quaternion.copy(camera.quaternion)

    const reveal = nodeUniforms.uReveal.value
    for (let i = 0; i < NODE_COUNT; i++) nodeFlares[i] *= 1 - Math.min(1, delta * 2.4)

    for (const signal of signals) {
      signal.t += delta * signal.speed
      const i3 = signal.index * 3

      if (signal.t >= 1) {
        // Arrival: the node it reached lights up, then the signal is reused.
        if (!signal.inbound) nodeFlares[signal.node] = Math.min(1.6, nodeFlares[signal.node] + 1.1)
        launch(signal, false)
        signalIntensity[signal.index] = 0
        continue
      }

      if (signal.t < 0 || reveal < 0.4) {
        signalIntensity[signal.index] = 0
        continue
      }

      const target = nodeVectors[signal.node]
      const t = signal.inbound ? 1 - signal.t : signal.t
      // Ease-out on the way out, ease-in on the way back, so departures feel
      // like a push and returns feel like they are falling home.
      const shaped = signal.inbound ? t * t : 1 - Math.pow(1 - t, 2.2)
      signalPositions[i3] = target.x * shaped
      signalPositions[i3 + 1] = target.y * shaped
      signalPositions[i3 + 2] = target.z * shaped

      // Fade in and out at the ends of the trip rather than popping.
      signalIntensity[signal.index] = Math.sin(Math.min(1, signal.t) * Math.PI) * reveal
    }

    nodeGeometry.attributes.aFlare.needsUpdate = true
    signalGeometry.attributes.position.needsUpdate = true
    signalGeometry.attributes.aColor.needsUpdate = true
    signalGeometry.attributes.aIntensity.needsUpdate = true
  }

  function render() {
    renderer.render(scene, camera)
  }

  function resize() {
    const width = canvas.clientWidth || 1
    const height = canvas.clientHeight || 1
    renderer.setSize(width, height, false)
    camera.aspect = width / height
    camera.updateProjectionMatrix()
  }

  function setPointer(x, y) {
    pointer.x = x
    pointer.y = y
  }

  // The entrance: core first, then the network builds outward, then traffic
  // starts. Paused until the panel is actually on screen.
  function intro() {
    const timeline = gsap.timeline({ paused: true, defaults: { ease: "power2.out" } })
    timeline
      .to(coreUniforms.uOpacity, { value: 1, duration: 0.9 }, 0)
      .to(coreMesh.scale, { x: 1, y: 1, z: 1, duration: 1.5, ease: "power3.out" }, 0)
      .to(haloUniforms.uOpacity, { value: 0.75, duration: 1.6 }, 0.15)
      .to(nodeUniforms.uReveal, { value: 1, duration: 2.6, ease: "power2.inOut" }, 0.35)
      .to(linkMaterial, { opacity: 0.55, duration: 1.8 }, 0.8)
    return timeline
  }

  function dispose() {
    scene.traverse((object) => {
      if (object.geometry) object.geometry.dispose()
      if (object.material) object.material.dispose()
    })
    renderer.dispose()
    // Frees the GPU context immediately instead of waiting for GC, which
    // matters because Turbo can mount this panel many times in one session.
    renderer.forceContextLoss?.()
  }

  return { advance, render, resize, setPointer, intro, dispose }
}
