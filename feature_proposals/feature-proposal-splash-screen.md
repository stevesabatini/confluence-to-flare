# Feature proposal: animated splash/loading screen

## Context

The "Confluence To Flare" macOS SwiftUI app at `/Users/steve/Documents/Claude Code Projects/mac_confluence_to_flare/swift-app` connects to Confluence and pulls release note data on launch (currently showing ~100 release notes). This creates a noticeable loading period before the split-pane UI is ready. This proposal adds a polished, animated splash screen that masks the Confluence data fetch, giving users visual feedback that the app is alive and working.

The app already has a dark theme, a distinctive blue-to-green wave/ribbon logo (512.png in the asset catalog), and window title "Confluence To Flare". The splash screen should feel like a natural extension of the existing visual identity.

---

## Design intent

The splash screen should feel purposeful — it's not decorative filler, it's tied to real initialization work (service connection + data fetch). The animation runs continuously until data is ready, then transitions smoothly to the main content view. The overall pacing should feel calm and professional, not frenetic.

An interactive prototype of the visual concept is available here:
https://claude.ai/chat/ *(refer to the conversation where this was designed — the animated splash with orbital dots, breathing logo, and progress bar)*

---

## Animation sequence (total entrance ~5 seconds at 0.8x speed)

The animation unfolds in four overlapping phases. All timings below are at the preferred 0.8x playback speed (i.e., the base animation duration is ~5 seconds for the entrance, with the orbital animation continuing indefinitely until loading completes).

### Phase 1 — Logo entrance (0s–1.25s)
- Display the app's actual logo image (512.png from the asset catalog — the blue-to-green wave/ribbon mark) centered in the window, sized to roughly 80–100pt
- Logo scales from 0.6× to 1.0× with an ease-out curve
- Opacity fades from 0 to 1 simultaneously
- A subtle radial glow appears behind the logo — use a blurred circle with ~15% opacity, tinted with the logo's blue (#1E90FF range) to complement the wave shapes
- Once fully visible, the logo enters a gentle "breathing" loop: scale oscillates between 1.0× and 1.02× with an ease-in-out animation (~1.5s period), continuing until the loading completes

### Phase 2 — Orbital ring and data particles (0.75s–2.5s)
- An elliptical ring fades in and expands from zero to full size around the logo (rx ~90, ry ~35 relative to a centered coordinate system)
- Three small circles ("data particles") appear staggered, each orbiting at a different radius:
  - Dot 1: largest (3pt), full orbit radius, brightest
  - Dot 2: medium (2.5pt), 85% orbit radius, slightly dimmer
  - Dot 3: smallest (2pt), 70% orbit radius, most subtle
- Orbital motion is continuous (not keyframed stops) using elapsed-time-based trigonometry
- Preferred orbit style: elliptical (but figure-8 is a nice alternative — consider making this configurable)
- The orbital animation loops indefinitely until loading completes

### Phase 3 — Text reveal (1.75s–3s)
- App name "Confluence To Flare" appears centered below the logo with a fade-up effect (opacity 0→1, y-offset slides up ~10pt)
- Font: system font, 20pt, semibold, letter-spacing ~2pt, white on dark background
- Status text appears 0.5s after the app name: smaller (11pt), muted color (#94a3b8 equivalent), letter-spacing ~3pt
- Status text content should be bound to actual loading state, e.g.:
  - "CONNECTING TO CONFLUENCE"
  - "LOADING RELEASE NOTES"
  - "PREPARING WORKSPACE"

### Phase 4 — Progress bar (2.75s–until complete)
- A thin progress bar (3pt height, rounded caps) fades in below the status text
- Background track: white at ~15% opacity
- Fill: gradient matching the app's accent color
- **The fill width should be bound to actual loading progress** — not a fake timer
- Use a smooth ease-out curve on the width animation so it doesn't jump

---

## Architecture recommendations

### View structure

```
App (@main)
├── WindowGroup
│   ├── RootView (manages splash vs. main content)
│   │   ├── SplashView (shown while loading)
│   │   └── MainContentView (existing app content)
```

`RootView` should observe a loading state (e.g., from an `@ObservableObject` or `@Observable` service) and use a conditional with `withAnimation` to transition between splash and main content.

### SplashView implementation approach

- Use `TimelineView(.animation)` to drive the orbital particle positions — this gives smooth, continuous animation without stacking discrete `.animation()` modifiers
- Compute dot positions from elapsed time using basic trig: `x = cx + rx * cos(angle)`, `y = cy + ry * sin(angle)` where `angle = elapsedTime / orbitPeriod`
- The phased entrance (logo → ring → text → progress) works well with `.onAppear` plus staggered `.animation(.easeOut.delay(n))` on each element
- The breathing effect on the logo is a simple `.scaleEffect()` driven by a repeating animation that starts after the entrance completes
- The radial glow can be a `Circle()` with `.blur(radius: 40)` and the brand blue (#2196F3) at ~12% opacity

### Loading state binding

The progress bar and status text should be driven by a `@Published` property on whatever service class handles the initial data fetch. Something like:

```swift
enum LoadingPhase: String {
    case connecting = "CONNECTING TO CONFLUENCE"
    case fetching = "LOADING RELEASE NOTES"
    case preparing = "PREPARING WORKSPACE"
    case complete = ""
}

class AppLoader: ObservableObject {
    @Published var phase: LoadingPhase = .connecting
    @Published var progress: Double = 0.0  // 0.0 to 1.0
    @Published var isComplete: Bool = false
}
```

### Transition to main content

When loading completes:
1. Let the progress bar fill to 100%
2. Brief hold (~0.3s) so the user registers completion
3. Fade out the entire splash with `.opacity` transition
4. Fade in the main content view
5. Use `withAnimation(.easeInOut(duration: 0.5))` for the swap

### Window styling for the splash

The app already uses a dark theme (visible in the current build), so the splash background should match seamlessly. Consider:
- `.windowStyle(.hiddenTitleBar)` — removes the "Confluence To Flare" title bar during splash for a cleaner look
- Background: #1B1F2E (matching the existing app chrome)
- Restore normal window chrome (with the "Confluence To Flare" title) when transitioning to the main split-pane content view

Since the app is already dark-themed, the transition from splash to main content should be nearly seamless — the backgrounds are the same family of dark navy.

---

## Color palette

These colors are derived from the app's existing visual identity: the blue-to-green wave logo and dark UI chrome visible in the current build.

| Element | Color | Notes |
|---------|-------|-------|
| Background | #1B1F2E | Deep navy — matches the app's existing dark chrome and the logo background |
| Logo | Use actual 512.png | The blue-to-green wave/ribbon mark from the asset catalog |
| Orbital ring | #2196F3 → #4CAF50 | Blue-to-green gradient echoing the logo's color flow, at ~40% opacity |
| Dot 1 | #42A5F5 | Bright blue — matches the upper wave strokes in the logo |
| Dot 2 | #26C6DA | Teal/cyan — the transitional color between blue and green |
| Dot 3 | #66BB6A | Soft green — matches the lower wave strokes in the logo |
| App name text | #FFFFFF | White |
| Status text | #94a3b8 | Muted blue-gray — complements the dark background |
| Progress track | #FFFFFF at 15% | Subtle white |
| Progress fill | Linear gradient #2196F3 → #4CAF50 | Blue-to-green, matching the logo's signature color flow |
| Radial glow | #2196F3 at 12% | Soft blue glow behind the logo |

The key principle: the splash should feel like a natural extension of the existing app. The blue-to-green gradient is the brand signature — it should carry through the orbital dots and progress bar so everything feels cohesive.

---

## What to keep in mind

- The animation should feel alive but not busy. The 0.8x speed gives it a calm, confident rhythm.
- The splash is functional, not decorative — tie the progress bar to actual loading state rather than faking progress on a timer. If loading finishes early, the splash should exit early (after at least ~2 seconds to avoid a jarring flash).
- Minimum display time: even if data loads instantly, show the splash for at least 2 seconds so the animation has time to register. This prevents the "flash of splash" problem.
- Dark mode considerations: the app is already dark-themed, so the splash background (#1B1F2E) should match the existing UI chrome. No special light/dark switching is needed — the splash is always dark, and the main content view is already dark.
- Accessibility: ensure the status text provides meaningful information for screen readers. Consider adding `accessibilityLabel` to the progress indicator.

---

## Files to create/modify

- **New:** `SplashView.swift` — the animated splash screen view
- **New:** `AppLoader.swift` (or similar) — observable loading state, unless existing service classes already expose this
- **Modify:** The app's root view or `@main` App struct — to wrap content in a conditional that shows splash vs. main content
- **Modify:** Window configuration — to apply dark background / hidden title bar during splash (optional enhancement)

---

## Out of scope for this feature

- Sound effects or haptics
- Onboarding flow or first-run experience
- Localization of status text (can be added later)

---

## Reference assets

- **App logo:** `512.png` in the asset catalog — the blue-to-green wave/ribbon mark on dark navy background. This is the actual image to display in the splash, not a placeholder.
- **App screenshot:** See the current build for reference on the dark theme colors, split-pane layout, and window chrome style that the splash should transition into.
