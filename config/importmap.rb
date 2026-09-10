# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# three.js and GSAP power the sign-in panel's scene. Vendored rather than
# pinned at a CDN: a login screen should not stop looking like itself because
# somebody else's edge node is having a bad day, and it keeps the page free of
# third-party requests.
#
# Both are single-file ESM bundles on purpose. Propshaft digests filenames, so
# a multi-file build's relative imports (three's `./three.core.js`) would
# resolve to paths that do not exist once fingerprinted.
#
# preload: false is load-bearing, not a tweak. Pins are preloaded by default,
# and a <link rel="modulepreload"> is a download: left on, every page in the
# application -- dashboard, calendar, inbox -- would fetch 750KB to draw a
# decoration that only exists on two screens. Turned off, the bytes are
# requested by the panel's dynamic import and nowhere else.
pin "three", to: "three.js", preload: false
pin "gsap", to: "gsap.js", preload: false
# From three's examples/jsm. It imports the bare specifier "three", which the
# pin above resolves, so it needs no bundling of its own.
pin "css3d-renderer", to: "css3d_renderer.js", preload: false
pin_all_from "app/javascript/prachar", under: "prachar", preload: false
