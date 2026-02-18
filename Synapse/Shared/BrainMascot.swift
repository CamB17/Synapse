import SwiftUI

struct BrainMascot: View {
    enum Expression: Equatable {
        case neutral
        case balanced
        case proud
    }

    var expression: Expression = .balanced
    var size: CGFloat = 64

    private var assetName: String {
        switch expression {
        case .neutral: return "mascot_brain_neutral"
        case .balanced: return "mascot_brain_balanced"
        case .proud: return "mascot_brain_proud"
        }
    }

    private var frameWidth: CGFloat {
        // Mascot exports are approximately 3:2. Preserve full artwork at fixed height.
        size * 1.5
    }

    var body: some View {
        Image(assetName)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: frameWidth, height: size)
            .accessibilityHidden(true)
    }
}

