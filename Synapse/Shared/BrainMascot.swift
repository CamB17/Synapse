import SwiftUI

enum BrainMascot {
    enum Expression: Equatable {
        case neutral
        case balanced
        case proud
    }

    static func imageName(for expression: Expression) -> String {
        switch expression {
        case .neutral: return "mascot_brain_neutral"
        case .balanced: return "mascot_brain_balanced"
        case .proud: return "mascot_brain_proud"
        }
    }
}

struct BrainMascotView: View {
    let imageName: String
    @ObservedObject var reactor: BrainReactionController
    var size: CGFloat = 112

    private var frameWidth: CGFloat {
        size * 1.5
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent)
                .frame(width: size * 0.86, height: size * 0.86)
                .blur(radius: 20)
                .opacity(Double(reactor.glow))

            Image(imageName)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: frameWidth, height: size)

            Image(systemName: "sparkles")
                .font(Theme.Typography.iconCompact.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent2.opacity(0.95))
                .opacity(Double(reactor.sparkle))
                .scaleEffect(0.82 + (reactor.sparkle * 0.28))
                .offset(reactor.sparkleOffset)
        }
        .frame(width: frameWidth, height: size)
        .scaleEffect(reactor.scale)
        .accessibilityHidden(true)
        .animation(.snappy(duration: 0.18), value: reactor.scale)
        .animation(.snappy(duration: 0.18), value: reactor.glow)
        .animation(.snappy(duration: 0.16), value: reactor.sparkle)
        .animation(.snappy(duration: 0.16), value: reactor.sparkleOffset)
    }
}
