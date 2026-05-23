# Cycle Browsing Profile — Architecture & Privacy Engineering

> Single-persona, full-app identity isolation for iOS 18+ / iOS 26+ with one-button
> cycle + cold-start. Defends against ThumbmarkJS, FingerprintJS, PerimeterX, DataDome
> signal collection on the client side.

---

## 1. Executive Summary & Privacy Risk Assessment

**Goal.** The entire app — every `WKWebView` *and* every `URLSession` request — must
appear to be one coherent, believable, high-end iOS device. Pressing **Cycle
Profile** replaces that device with a completely different but equally believable
one, after a clean async wipe and cold-start.

**Why "believable, not unique."** Every fingerprinting library on the market
correlates *internal consistency* of signals against a database of real devices.
Aggressive randomization makes the device *more* unique, not less, because real
iPhones of the same model produce near-identical signatures. The system therefore:

- maintains a **matrix of 10 hand-validated real iOS personas**,
- applies **deterministic** seeded modifications (same persona ⇒ same canvas/audio hash),
- never lets the page see a UA/platform/hardware mismatch (the root cause of `tampering: true`).

**Residual risk we cannot fully eliminate on iOS:**

1. **TLS JA3/JA4 fingerprint.** Apple's Network framework re-uses the system TLS
   stack. The ClientHello cipher order is iOS-shaped — which is consistent with
   the iOS personas, but means we cannot pose as Chrome-on-Windows convincingly.
2. **WebKit version is fixed.** A persona pretending to be iOS 18.6 cannot offer
   a WebKit feature only present in iOS 26 (and vice versa). The matrix is built
   accordingly.
3. **App Store termination policy.** `exit(0)` is not compliant. We ship both
   modes and toggle via the `USE_SOFT_RESTART` compile flag.

---

## 2. Identification Component Matrix

### Top 7 highest-value iOS signals to neutralize

| Signal | Source | Why it leaks identity | How we neutralize |
|---|---|---|---|
| **User-Agent vs. platform mismatch** | `Sec-CH-UA*`, `navigator.platform`, `navigator.userAgent` | Triggers `tampering: true` in FingerprintJS | Persona owns *all three*; no manual override |
| **WebGL `UNMASKED_RENDERER`** | `WEBGL_debug_renderer_info` | Real Safari iOS always returns `"Apple GPU"` | Wrapped `getParameter` returns persona's GPU string |
| **Canvas hash** | `toDataURL`, `getImageData` | Per-pixel stable across same device family | Persona-seeded 1-byte deterministic XOR — same persona = same hash |
| **AudioContext fingerprint** | `OfflineAudioContext.getChannelData` | Float32 buffer hashable across runs | Deterministic ±1e-7 offset seeded by persona |
| **`navigator.userAgentData`** | UA-CH | Safari iOS does NOT expose it — Chrome impersonation gets caught | Hidden (returns `undefined` shape matching Safari) when persona is Safari |
| **Timezone vs. IP geolocation** | `Intl.DateTimeFormat.resolvedOptions().timeZone` + `Date.getTimezoneOffset()` | Mismatched TZ flags VPN/proxy | Persona TZ; user-controllable in advanced |
| **Plugins / fonts / hardwareConcurrency** | `navigator.plugins`, `document.fonts.check`, `navigator.hardwareConcurrency` | Real iOS has `plugins.length === 0`, exposes 6 cores on A17/A18 | Persona forces `[]` and persona's exact core count |

### Native-chain inspection vectors

Modern detection scripts run all of these on every override:

- `Function.prototype.toString.call(getParameter)` → must return `function getParameter() { [native code] }`.
- `Object.getOwnPropertyDescriptor(obj, 'platform')` → `{get: ƒ, set: undefined, enumerable: false, configurable: true}`.
- Prototype walk: `obj.constructor.prototype.method === obj.method`.
- Setter side-effect probes: `obj.platform = 'X'; obj.platform` (must not reflect).
- Timing: `performance.now()` deltas around wrapped calls.

`PersonaScript` addresses these via the `wrapMethod` helper which (a) reassigns
`wrapped.toString` to return the original `nativeStr`, (b) installs the wrapper
on the prototype (not the instance), and (c) uses
`Object.defineProperty(obj, prop, {get, configurable: true, enumerable: false})`
to match real native descriptors.

### Server-side correlation

Fingerprint vendors compute a confidence score by joining client signals against
**HTTP/2 settings frame**, **header order**, **TLS JA3/JA4**, and **IP ASN**. Our
mitigations:

- **Header order**: `URLSessionConfiguration.httpAdditionalHeaders` plus a
  persona-built dictionary in the order Safari emits.
- **`.ephemeral`** session so resumption cookies / cached connection state
  cannot persist past a cycle.
- **HTTP/2** is on by default; we pin `tlsMinimumSupportedProtocolVersion = .TLSv12`.
- **JA3/JA4 is iOS-shaped**, which matches every persona in the matrix. (Acceptable.)

---

## 3. Swift 6.2 Architecture

```
┌──────────────────────────────┐         ┌─────────────────────────┐
│   ProfileManager (MainActor) │ ───────▶│   PersonaVault (Keychain)│
│   - activePersona            │         └─────────────────────────┘
│   - makeWebViewConfiguration │
│   - network: PersonaURLSession│         ┌─────────────────────────┐
└─────────────┬────────────────┘         │   PersonaMatrix          │
              │                          │   - all: [BrowsingPersona]│
              │                          │   - pickNext(excluding:)  │
              │                          └─────────────────────────┘
   ┌──────────┴──────────┐                       ▲
   │                     │                       │
   ▼                     ▼                       │
WKWebView           URLSession                   │
(BrowserView)       (any service)                │
                                                 │
              ┌──────────────────────────────────┘
              │
       CycleCoordinator (MainActor)
       - cycle() async
       - emits Step events via onStep
              │
              ▼
       CycleProfileViewModel (@Observable)
              │
              ▼
       CycleOverlayView (SwiftUI)
```

**Isolation strategy.** The project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
so `ProfileManager`, `CycleCoordinator`, and `PersonaURLSession` are
MainActor-isolated by default — which is the correct isolation for vending
`WKWebViewConfiguration` (itself MainActor-bound). `BrowsingPersona`,
`PersonaMatrix`, `PersonaScript`, and `PersonaVault` are explicitly `nonisolated`
because they're pure Codable / pure functions and need to be callable from
background contexts (Keychain reads, JSON encoding).

---

## 4. Refresh & Cold-Start Sequence

```
                     ┌─────────────────────────────┐
   User taps Cycle ─▶│ CycleProfileViewModel.start │
                     └──────────────┬──────────────┘
                                    │
              ┌─────────────────────┴─────────────────────┐
              │  CycleCoordinator.cycle() async           │
              └─────────────────────┬─────────────────────┘
                                    │
   1. Post .willCycle notification (BrowserView dismisses)
   2. await WKWebsiteDataStore.default().removeData(.distantPast)
      • default store
      • EVERY identifier-based store (per-profile cookie jars) on iOS 17+
   3. HTTPCookieStorage.shared.removeCookies(since:)
      URLCache.shared.removeAllCachedResponses()
      Wipe NSTemporaryDirectory + Caches directory
      Remove identity-related UserDefaults keys
   4. PersonaVault.wipe() ; pick persona ≠ previous ; PersonaVault.save(next)
      ProfileManager.shared.sealNewPersona(next)
      Post .didCycle notification
   5. Hard cold-start:
        UIApplication.shared.perform(Selector("suspend"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(0) }
```

**Safety invariants.**

- Every `removeData` call is `await withCheckedContinuation` — we never exit
  early. This is what was leaking before.
- The Keychain write is committed *before* the new persona is announced — so
  even if the process is killed mid-cycle, the next launch reads a coherent
  persona (no torn state).
- `URLSession.invalidateAndCancel()` is called inside `PersonaURLSession.rebuild`
  so any in-flight requests are aborted before the persona swap.

---

## 5. Protective Script Library

See `Services/PersonaScript.swift`. Highlights:

- **`defineGetter`**: sets `{get, configurable: true, enumerable: false}` matching real native descriptors.
- **`wrapMethod`**: replaces a prototype method while:
  - capturing the original's `Function.prototype.toString` output,
  - reassigning `wrapped.toString` to return that same string,
  - preserving `.name`.
- **Deterministic xorshift64\***  PRNG seeded by `persona.renderSeed` — so the same persona always produces the same canvas/audio hash. Reset with `reseed()` at the start of every wrapped call.
- **Canvas**: `toDataURL`, `toBlob`, `getImageData`, `measureText` all wrapped. The `getImageData` tweak is a single-byte XOR (visually invisible, stable).
- **WebGL**: `getParameter` answers persona-correct strings for `UNMASKED_RENDERER_WEBGL (0x9246)`, `UNMASKED_VENDOR_WEBGL (0x9245)`, `RENDERER (0x1F01)`, `VENDOR (0x1F00)`.
- **AudioContext**: `OfflineAudioContext.sampleRate` pinned to persona's `audioSampleRate`; `AudioBuffer.getChannelData` adds ±1e-7 deterministic offset.
- **Fonts**: `document.fonts.check` whitelisted to the persona's iOS font list.
- **`userAgentData`**: returns Safari-shaped empty when persona is Safari.

---

## 6. Persona Matrix

| ID | Device | iOS | Screen pt | DPR | Cores | Fonts | UA family |
|---|---|---|---|---|---|---|---|
| iphone15pro_ios18 | iPhone 15 Pro | 18.6 | 393×852 | 3 | 6 | iPhone | Safari Mobile |
| iphone15promax_ios18 | iPhone 15 Pro Max | 18.6 | 430×932 | 3 | 6 | iPhone | Safari Mobile |
| iphone16_ios18 | iPhone 16 | 18.6 | 393×852 | 3 | 6 | iPhone | Safari Mobile |
| iphone16pro_ios26 | iPhone 16 Pro | 26.1 | 402×874 | 3 | 6 | iPhone | Safari Mobile |
| iphone16promax_ios26 | iPhone 16 Pro Max | 26.1 | 440×956 | 3 | 6 | iPhone | Safari Mobile |
| iphone16e_ios26 | iPhone 16e | 26.1 | 390×844 | 3 | 6 | iPhone | Safari Mobile |
| ipadpro11_m4_ios18 | iPad Pro 11" M4 | 18.6 | 834×1194 | 2 | 10 | iPad | Safari Desktop-class |
| ipadpro13_m4_ios26 | iPad Pro 13" M4 | 26.1 | 1024×1366 | 2 | 10 | iPad | Safari Desktop-class |
| ipadair_m2_ios18 | iPad Air M2 | 18.6 | 820×1180 | 2 | 8 | iPad | Safari Desktop-class |
| ipadmini7_ios26 | iPad mini 7 | 26.1 | 744×1133 | 2 | 6 | iPad | Safari Desktop-class |

`pickNext(excluding:)` guarantees no two cycles produce the same persona in a row.

---

## 7. Network Layer Alignment

| What we control | How |
|---|---|
| `User-Agent` | `WKWebView.customUserAgent` + `URLSession` `httpAdditionalHeaders` |
| `Accept-Language` | Persona header, injected into both stacks |
| `Sec-CH-UA*` | Persona-aware (set only when persona is Chromium) |
| `Sec-Fetch-*` | Defaults to `none / navigate / document` |
| HTTP/2 | URLSession default |
| Cookie policy | `HTTPCookieStorage.shared.cookieAcceptPolicy = .always` |
| Disk persistence | `.ephemeral` session config — no resumption across cycle |

| What we cannot control on iOS | Why |
|---|---|
| TLS ClientHello (JA3/JA4) cipher order | Apple's TLS stack is fixed |
| HTTP/2 SETTINGS frame layout | Network framework owns it |
| Order of *some* headers (URLSession reorders alphabetically in CFNetwork) | Best-effort only |

These residual signals are **iOS-shaped**, which is consistent with our
all-iOS persona matrix — so they don't trip "tampering" detection.

---

## 8. Implementation Order, Testing & iOS Gotchas

**Implementation order shipped:**

1. Models (`BrowsingPersona`, `PersonaMatrix`).
2. Services (`PersonaScript`, `PersonaURLSession`, `ProfileManager`, `CycleCoordinator`).
3. ViewModels (`CycleProfileViewModel`, `PersonaSettingsViewModel`).
4. Views (`PersonaSettingsSection`, `CycleOverlayView`).
5. Wire-up: `BrowserView` + `BrowserRequestFactory` + `SettingsView`.

**Testing methodology.**

- `https://demo.fingerprint.com/playground` — verify `suspect_score`,
  `tampering`, `tampering_confidence`.
- `https://browserleaks.com/canvas`, `/webgl`, `/audio`, `/fonts`.
- `https://abrahamjuliot.github.io/creepjs/` — comprehensive consistency check.
- `https://amiunique.org/fp` — same-persona twin verification (multiple cycles → same persona id → same fingerprint).

**Known iOS gotchas.**

- `WKProcessPool` sharing leaks process-wide caches. We do not share a pool;
  each `WKWebsiteDataStore` is per-profile.
- ITP (Intelligent Tracking Prevention) silently downgrades third-party cookies
  after 7 days even with `.always`. The persistent cookie injection on
  `didFinish` is the workaround.
- WebContent is out-of-process; our script must be installed at
  `.atDocumentStart` *and* on the configuration, not the view, so it survives
  process recycles.
- iPadOS Safari defaults to desktop UA — `PersonaMatrix.ipad` reflects that.
- `WKWebsiteDataStore(forIdentifier:)` is iOS 17+ only — we guard the
  enumeration with `#available`.

**App Store toggle.** Define `USE_SOFT_RESTART` in build settings to switch
`CycleCoordinator.performHardColdStart()` from `exit(0)` to a soft window
rebuild before App Store submission.
