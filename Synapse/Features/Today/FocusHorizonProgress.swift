import SwiftUI

enum FocusTimerMode {
    case countdown
    case stopwatch
}

struct FocusHorizonProgress: View {
    let progress: Double
    let mode: FocusTimerMode
    let isRunning: Bool
    var trackColor: Color = Theme.textSecondary.opacity(0.20)
    var fillColor: Color = Theme.accent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var leadingGlowPulse = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)

                switch mode {
                case .countdown:
                    let clamped = CGFloat(min(1, max(0, progress)))
                    let fillWidth = max(3, width * clamped)

                    Capsule(style: .continuous)
                        .fill(fillColor.opacity(isRunning ? 0.88 : 0.52))
                        .frame(width: fillWidth)
                        .animation(reduceMotion ? .linear(duration: 0) : .linear(duration: 0.12), value: progress)
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(fillColor.opacity(isRunning ? 0.60 : 0.28))
                                .frame(width: 9, height: 9)
                                .blur(radius: 3)
                                .scaleEffect(leadingGlowPulse ? 1.18 : 0.94)
                                .opacity(leadingGlowPulse ? 1.0 : 0.72)
                        }
                case .stopwatch:
                    if reduceMotion || !isRunning {
                        Capsule(style: .continuous)
                            .fill(fillColor.opacity(0.28))
                            .frame(width: max(14, width * 0.18))
                    } else {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.001))
                            .overlay(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                fillColor.opacity(0.08),
                                                fillColor.opacity(0.32),
                                                fillColor.opacity(0.08)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(34, width * 0.24))
                                    .offset(x: shimmerOffset * (width + 44))
                                    .blendMode(.plusLighter)
                            }
                            .clipped()
                    }
                }
            }
        }
        .frame(height: 4)
        .onAppear {
            refreshShimmer()
            refreshLeadingGlowPulse()
        }
        .onChange(of: isRunning) { _, _ in
            refreshShimmer()
            refreshLeadingGlowPulse()
        }
        .onChange(of: reduceMotion) { _, _ in
            refreshShimmer()
            refreshLeadingGlowPulse()
        }
        .onChange(of: mode) { _, _ in
            refreshShimmer()
            refreshLeadingGlowPulse()
        }
    }

    private func refreshShimmer() {
        guard mode == .stopwatch, isRunning, !reduceMotion else {
            withAnimation(.none) {
                shimmerOffset = -1.0
            }
            return
        }

        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            shimmerOffset = 1.0
        }
    }

    private func refreshLeadingGlowPulse() {
        guard mode == .countdown, isRunning, !reduceMotion else {
            withAnimation(.none) {
                leadingGlowPulse = false
            }
            return
        }

        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            leadingGlowPulse = true
        }
    }
}
