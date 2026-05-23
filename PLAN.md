# Cycle Browsing Profile: actor-based persona system + protective JS + TLS-aligned network + hard cold-start

## What you'll be able to do

- Tap one **"Cycle Profile"** button to instantly become a completely different believable high-end iOS device (iPhone 15 Pro, 15 Pro Max, 16 Pro, 16 Pro Max, iPad Pro M4, etc.).
- Every web view and every native request inside the app speaks as that one device — same User-Agent, same languages, same timezone, same screen, same rendering quirks — top to bottom.
- Cycling wipes everything (cookies, caches, web data, snapshots of identity) and cold-starts the app from zero, so the previous profile leaves no trace.
- A new **Profile** tab in Settings shows the active persona (device, iOS version, locale, timezone, screen, GPU string) plus a big "Cycle Now" button.

## How it'll feel

- **One-button drama**: cycle button pulses, a full-screen "Resetting identity…" overlay appears with a progress checklist (Stopping browsers → Clearing web data → Wiping caches → Sealing new identity → Cold start), then the app fully relaunches into the new persona.
- **Always consistent**: no more random per-tab variation. The whole app is one device for its whole lifetime, until you cycle.
- **Believable, not random**: each persona is hand-tuned from a real device family — no noisy canvas randomization that makes you *more* unique than a real phone.

## Screens that change

- **Settings → Profile** (new section): shows current persona card (device name, iOS, locale, timezone, screen, GPU), "Cycle Profile" button, and an advanced disclosure with the raw User-Agent and Accept-Language.
- **Cycle Overlay** (new full-screen sheet): animated progress checklist during the async wipe, then triggers cold restart.
- **Browser** unchanged visually, but every webview now sources its config from the central `ProfileManager`.

## Under the hood (high level)

1. **`BrowsingPersona` model** — immutable Codable struct holding every signal for one real device family: UA, platform, vendor, screen, DPR, hardwareConcurrency, deviceMemory, GPU renderer string, audio sample rate, font list, timezone, languages, sec-ch-ua headers, accept-language, TLS/HTTP profile id.
2. **Persona Matrix** — 10 hand-curated high-end iOS personas (iPhone 15 Pro, 15 Pro Max, 16, 16 Pro, 16 Pro Max, 16e, iPad Pro 11" M4, iPad Pro 13" M4, iPad Air M2, iPad mini 7) × a couple of iOS versions (18.x, 26.x). Each entry has validated real-world values, not synthesized.
3. **`ProfileManager` actor** (Swift 6.2) — single source of truth. Owns the active persona, persists encrypted in Keychain, and is the *only* place that vends `WKWebViewConfiguration` and `URLSessionConfiguration`. Every browser view requests its config from here so consistency is structural, not by convention.
4. **Cycle + cold-start sequence** — proper async/await pipeline:
   - Post `.appWillCycleProfile` (browsers tear down web views).
   - `await WKWebsiteDataStore.default().removeData(...)` for *all* data types since distantPast (must `await`, no early exit — this was the leak you flagged).
   - Clear `HTTPCookieStorage.shared`, `URLCache.shared`, app-group caches, tmp dir, app support caches.
   - Clear UserDefaults keys related to identity + Keychain identity entry.
   - Pick new persona (never the same one twice in a row), seal into Keychain.
   - Schedule hard cold-start: `UIApplication.shared.perform(#selector(NSXPCConnection.suspend))` then `exit(0)` (the requested behaviour — flagged as App Store-risky in code comments).
5. **Protective JS library** (`PersonaScript.swift`) — battle-tested user scripts injected at `.atDocumentStart`, `forMainFrameOnly: false`. Uses constructor proxying and getter descriptors that preserve native chain:
   - `navigator` (platform, vendor, userAgent, languages, hardwareConcurrency, deviceMemory, maxTouchPoints, userAgentData with `getHighEntropyValues`).
   - `screen` (width/height/availWidth/availHeight/colorDepth/pixelDepth, devicePixelRatio via matchMedia).
   - `Intl.DateTimeFormat.resolvedOptions` + `Date.prototype.getTimezoneOffset`.
   - **Canvas** — `toDataURL`, `toBlob`, `getImageData`, `measureText` wrapped with **deterministic, persona-seeded** sub-pixel tweaks (same persona ⇒ same canvas hash, like real devices).
   - **WebGL** — `getParameter` (UNMASKED_RENDERER/VENDOR returns persona-correct Apple GPU strings), `getExtension`, `getSupportedExtensions` filtered to the iOS Safari real set.
   - **AudioContext** — sampleRate + `getChannelData` deterministic offset seeded by persona.
   - **Font enumeration** — `measureText` returns persona's real iOS font widths only.
   - All wrappers preserve `.toString()` (returns `function getParameter() { [native code] }`), `Object.getOwnPropertyDescriptor` shapes, and `prototype` chains. No setter side-effects.
6. **TLS / network alignment** — new `PersonaURLSession` actor:
   - Builds a `URLSessionConfiguration` per persona: forced `Accept-Language`, `User-Agent`, `Sec-CH-UA*`, `Sec-Fetch-*` defaults, deterministic header order via a custom request adapter.
   - Ephemeral configuration only (`.ephemeral`) so disk caches can't survive a cycle.
   - HTTP/2 preferred, ALPN order matching iOS Safari.
   - Replaces direct `URLSession.shared` usage in services (history fetcher etc.) with `ProfileManager.shared.session`.
   - Documented note: real JA3/JA4 TLS fingerprint can't be fully reshaped from Apple's stack — we align everything we *can* control and document what we can't.
7. **MVVM preservation** — additions:
   - `Models/BrowsingPersona.swift`, `Models/PersonaMatrix.swift`
   - `Services/ProfileManager.swift` (actor), `Services/PersonaScript.swift`, `Services/PersonaURLSession.swift`, `Services/CycleCoordinator.swift`
   - `ViewModels/CycleProfileViewModel.swift`, `ViewModels/PersonaSettingsViewModel.swift`
   - `Views/PersonaSettingsSection.swift`, `Views/CycleOverlayView.swift`
   - Refactor `BrowserView` / `IdentityService` to read everything from `ProfileManager` (the old `IdentitySettings` becomes a thin adapter).

## Deliverable doc

I'll also write `PROFILE_ARCHITECTURE.md` covering:
- Executive summary + risk assessment
- Identification component matrix (ThumbmarkJS / FingerprintJS / PerimeterX / DataDome signals, with the 5–7 highest-value iOS signals to neutralize)
- Actor architecture diagrams
- Full async cold-start sequence with safety invariants
- Protective JS template index
- Persona matrix table
- Network alignment (what we control vs. what we can't on iOS)
- Testing methodology (demo.fingerprint.com, browserleaks, creepjs, amiunique)
- Known iOS gotchas (WKProcessPool sharing, ITP, out-of-process WebKit, etc.)

## Important honest caveat (in the doc, not hidden)

- `exit(0)` cold-start is **not App Store compliant** — Apple's review guidelines forbid programmatic termination. I'll implement it as you asked, mark it clearly in code comments, and add a `#if APPSTORE` compile flag that switches to soft restart so you can flip it before submission.
- iOS TLS stack (JA3/JA4) can't be fully spoofed without a custom networking library; we align everything in user-space and document the residual signal.

After approval I'll implement everything, run `runChecks` on `ios`, and iterate until the build is green.