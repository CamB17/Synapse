import SwiftUI

struct FocusThinProgressView: View {
    let remainingFraction: Double?
    let isPaused: Bool

    @State private var isBreathing = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width)
            ZStack {
                Capsule(style: .continuous)
                    .fill(Theme.surface2.opacity(0.96))

                if let remainingFraction {
                    Capsule(style: .continuous)
                        .fill(Theme.accent.opacity(isPaused ? 0.46 : 0.84))
                        .frame(width: width * CGFloat(min(1, max(0, remainingFraction))), alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Capsule(style: .continuous)
                        .fill(Theme.accent.opacity(isPaused ? 0.34 : 0.62))
                        .frame(width: min(28, max(16, width * 0.14)))
                        .scaleEffect(isBreathing ? 1.18 : 0.92, anchor: .center)
                        .opacity(isBreathing ? 0.78 : 0.38)
                }
            }
        }
        .frame(height: 3)
        .animation(
            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
            value: isBreathing
        )
        .onAppear {
            refreshBreathingState()
        }
        .onChange(of: isPaused) { _, _ in
            refreshBreathingState()
        }
        .onChange(of: remainingFraction == nil) { _, _ in
            refreshBreathingState()
        }
    }

    private func refreshBreathingState() {
        isBreathing = remainingFraction == nil && !isPaused
    }
}
