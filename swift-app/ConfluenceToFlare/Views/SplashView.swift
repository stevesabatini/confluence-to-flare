import SwiftUI

/// Animated splash screen shown while the app loads data from Confluence.
///
/// Uses a phased entrance: logo → orbital ring with dots → text → progress bar.
/// All animations are driven by `TimelineView(.animation)` for smooth continuous motion.
/// The progress bar and status text are bound to real loading state, not timers.
struct SplashView: View {
    /// Current loading phase description (bound to PageListViewModel)
    let statusText: String
    /// Loading progress 0.0–1.0 (bound to PageListViewModel)
    let progress: Double
    /// When true, any still-pending entrance phases snap to completion
    let loadingComplete: Bool
    /// Called once the splash has finished its exit-ready state (all elements visible, progress at 100%)
    var onReadyToTransition: (() -> Void)? = nil

    // MARK: - Animation state

    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.6
    @State private var breatheScale: Double = 1.0
    @State private var ringOpacity: Double = 0
    @State private var ringScale: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 10
    @State private var statusOpacity: Double = 0
    @State private var statusOffset: CGFloat = 10
    @State private var progressOpacity: Double = 0
    @State private var dotsOpacity: Double = 0
    @State private var animationStarted = false
    @State private var entranceComplete = false
    @State private var hasSignaledReady = false

    // MARK: - Constants

    private let bgColor = Color(red: 0.106, green: 0.122, blue: 0.180) // #1B1F2E
    private let glowColor = Color(red: 0.129, green: 0.588, blue: 0.953) // #2196F3
    private let dotColors: [Color] = [
        Color(red: 0.259, green: 0.647, blue: 0.961), // #42A5F5
        Color(red: 0.149, green: 0.776, blue: 0.855), // #26C6DA
        Color(red: 0.400, green: 0.733, blue: 0.416), // #66BB6A
    ]
    private let gradientStart = Color(red: 0.129, green: 0.588, blue: 0.953) // #2196F3
    private let gradientEnd = Color(red: 0.298, green: 0.686, blue: 0.314)   // #4CAF50

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = animationStarted
                ? timeline.date.timeIntervalSince(animationStart ?? timeline.date)
                : 0.0

            ZStack {
                bgColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Logo + glow + orbital ring
                    ZStack {
                        // Radial glow
                        Circle()
                            .fill(glowColor.opacity(0.12))
                            .frame(width: 180, height: 180)
                            .blur(radius: 40)
                            .opacity(logoOpacity)

                        // Orbital ring
                        Ellipse()
                            .stroke(
                                LinearGradient(
                                    colors: [gradientStart.opacity(0.4), gradientEnd.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                            .frame(width: 180, height: 70)
                            .opacity(ringOpacity)
                            .scaleEffect(ringScale)

                        // Orbital dots
                        ForEach(0..<3, id: \.self) { index in
                            let dotConfig = dotConfigs[index]
                            let angle = elapsed / dotConfig.period * 2 * .pi + dotConfig.phaseOffset
                            let rx = 90.0 * dotConfig.radiusFraction
                            let ry = 35.0 * dotConfig.radiusFraction

                            Circle()
                                .fill(dotColors[index])
                                .frame(width: dotConfig.size, height: dotConfig.size)
                                .shadow(color: dotColors[index].opacity(0.6), radius: 4)
                                .offset(
                                    x: rx * cos(angle),
                                    y: ry * sin(angle)
                                )
                                .opacity(dotsOpacity * dotConfig.opacity)
                        }

                        // App logo
                        Image("AppIcon")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .opacity(logoOpacity)
                            .scaleEffect(logoScale * breatheScale)
                    }
                    .frame(height: 100)

                    Spacer().frame(height: 32)

                    // App title
                    Text("Confluence To Flare")
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(.white)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)

                    Spacer().frame(height: 12)

                    // Status text
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundColor(Color(red: 0.58, green: 0.64, blue: 0.72)) // #94a3b8
                        .opacity(statusOpacity)
                        .offset(y: statusOffset)

                    Spacer().frame(height: 20)

                    // Progress bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 200, height: 3)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    colors: [gradientStart, gradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, 200 * progress), height: 3)
                            .animation(.easeOut(duration: 0.4), value: progress)
                    }
                    .opacity(progressOpacity)
                    .accessibilityLabel("Loading progress: \(Int(progress * 100)) percent")

                    Spacer()
                }
            }
        }
        .onAppear {
            startEntrance()
        }
        .onChange(of: loadingComplete) { _, complete in
            if complete {
                accelerateEntrance()
            }
        }
    }

    // MARK: - Animation timing

    @State private var animationStart: Date?

    private struct DotConfig {
        let size: CGFloat
        let radiusFraction: Double
        let opacity: Double
        let period: Double
        let phaseOffset: Double
    }

    private let dotConfigs: [DotConfig] = [
        DotConfig(size: 6, radiusFraction: 1.0,  opacity: 1.0, period: 3.0, phaseOffset: 0),
        DotConfig(size: 5, radiusFraction: 0.85, opacity: 0.7, period: 4.0, phaseOffset: 2.1),
        DotConfig(size: 4, radiusFraction: 0.70, opacity: 0.5, period: 5.5, phaseOffset: 4.2),
    ]

    private func startEntrance() {
        animationStart = Date()
        animationStarted = true

        let reduceMotion = AccessibilitySettings.reduceMotion

        if reduceMotion {
            snapToFinalState(animated: false)
            entranceComplete = true
            if loadingComplete { signalReady() }
            return
        }

        // Phase 1: Logo entrance (0s–1.25s)
        withAnimation(.easeOut(duration: 1.25)) {
            logoOpacity = 1
            logoScale = 1.0
        }

        // Breathing loop starts after logo entrance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breatheScale = 1.02
            }
        }

        // Phase 2: Orbital ring + dots (0.75s–2.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeOut(duration: 1.5)) {
                ringOpacity = 1
                ringScale = 1
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                dotsOpacity = 1
            }
        }

        // Phase 3: Text reveal (1.75s–3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            withAnimation(.easeOut(duration: 0.6)) {
                titleOpacity = 1
                titleOffset = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
            withAnimation(.easeOut(duration: 0.6)) {
                statusOpacity = 1
                statusOffset = 0
            }
        }

        // Phase 4: Progress bar (2.75s–3.15s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) {
            withAnimation(.easeOut(duration: 0.4)) {
                progressOpacity = 1
            }
        }

        // Mark entrance as complete after all phases have finished (~3.15s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            entranceComplete = true
            if loadingComplete { signalReady() }
        }
    }

    /// When loading finishes before the entrance animation completes,
    /// snap any still-pending elements to their final state with a quick animation,
    /// then signal ready to transition.
    private func accelerateEntrance() {
        guard !hasSignaledReady else { return }

        if entranceComplete {
            // Entrance already done — signal immediately
            signalReady()
        } else {
            // Snap remaining elements into place with a quick animation
            withAnimation(.easeOut(duration: 0.3)) {
                snapToFinalState(animated: true)
            }

            // Give the snap animation time to land, then signal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                entranceComplete = true
                signalReady()
            }
        }
    }

    /// Set all entrance animation properties to their final values.
    private func snapToFinalState(animated: Bool) {
        logoOpacity = 1
        logoScale = 1
        ringOpacity = 1
        ringScale = 1
        dotsOpacity = 1
        titleOpacity = 1
        titleOffset = 0
        statusOpacity = 1
        statusOffset = 0
        progressOpacity = 1
    }

    /// Notify the parent that the splash is visually complete and ready to fade out.
    private func signalReady() {
        guard !hasSignaledReady else { return }
        hasSignaledReady = true

        // Brief hold so the user registers the completed state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onReadyToTransition?()
        }
    }
}

// MARK: - Accessibility helper

private enum AccessibilitySettings {
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
