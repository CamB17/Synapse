import SwiftUI

struct FocusAmbientBackground: View {
    let theme: FocusBackgroundTheme
    let intensity: Double
    let isRunning: Bool
    var isPaused: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        let tokens = theme.tokens
        let clampedIntensity = min(1, max(0, intensity))
        let scaleRange: ClosedRange<Double> = isPaused
            ? (1.0...1.06)
            : (
                isRunning
                ? (1.0...1.08)
                : (Double(tokens.breathingScaleRange.lowerBound)...Double(tokens.breathingScaleRange.upperBound))
            )
        let opacityRange: ClosedRange<Double> = isPaused
            ? (0.05...0.10)
            : (
                isRunning
                ? (0.08...0.16)
                : tokens.breathingOpacityRange
            )
        let driftX = reduceMotion ? 0 : (isBreathing ? 12.0 : -12.0)
        let driftY = reduceMotion ? 0 : (isBreathing ? -10.0 : 10.0)

        ZStack {
            tokens.base
                .ignoresSafeArea()

            LinearGradient(
                colors: tokens.gradientStops,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.7 + (clampedIntensity * 0.22))
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    tokens.radialGlow.opacity(
                        glowOpacity(opacityRange: opacityRange, intensity: clampedIntensity, tokens: tokens)
                    ),
                    tokens.radialGlow.opacity(0.001)
                ],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .scaleEffect(glowScale(scaleRange: scaleRange))
            .blur(radius: 6)
            .blendMode(.plusLighter)
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    tokens.radialGlow.opacity(
                        glowOpacity(opacityRange: opacityRange, intensity: clampedIntensity, tokens: tokens) * 0.42
                    ),
                    Color.clear
                ],
                center: .top,
                startRadius: 14,
                endRadius: 320
            )
            .blur(radius: 12)
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    tokens.radialGlow.opacity(
                        glowOpacity(opacityRange: opacityRange, intensity: clampedIntensity, tokens: tokens) * 0.28
                    ),
                    Color.clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 240
            )
            .scaleEffect(glowScale(scaleRange: scaleRange) * 0.98)
            .offset(x: driftX, y: driftY)
            .blur(radius: 18)
            .blendMode(.plusLighter)
            .ignoresSafeArea()
        }
        .onAppear {
            refreshBreathing()
        }
        .onChange(of: isRunning) { _, _ in
            refreshBreathing()
        }
        .onChange(of: isPaused) { _, _ in
            refreshBreathing()
        }
        .onChange(of: reduceMotion) { _, _ in
            refreshBreathing()
        }
    }

    private func glowScale(scaleRange: ClosedRange<Double>) -> CGFloat {
        guard !reduceMotion else {
            return CGFloat(scaleRange.lowerBound)
        }

        return CGFloat(isBreathing ? scaleRange.upperBound : scaleRange.lowerBound)
    }

    private func glowOpacity(
        opacityRange: ClosedRange<Double>,
        intensity: Double,
        tokens: FocusThemeTokens
    ) -> Double {
        let opacity = isBreathing ? opacityRange.upperBound : opacityRange.lowerBound
        let themeScale = min(2.0, max(0.35, tokens.radialGlowOpacity / 0.11))
        return opacity * intensity * themeScale
    }

    private func refreshBreathing() {
        guard !reduceMotion else {
            withAnimation(.none) {
                isBreathing = false
            }
            return
        }

        let cycle = isPaused ? 14.0 : (isRunning ? 8.0 : 9.0)
        withAnimation(.easeInOut(duration: cycle).repeatForever(autoreverses: true)) {
            isBreathing = true
        }
    }
}
