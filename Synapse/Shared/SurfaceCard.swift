import SwiftUI

enum SurfaceCardStyle {
    case primary
    case secondary
    case accentTint
}

private struct SurfaceCardModifier: ViewModifier {
    let style: SurfaceCardStyle
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Theme.surface
        case .secondary:
            return Theme.surface2
        case .accentTint:
            return Theme.accent.opacity(0.06)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary:
            return Theme.cardShadow()
        case .secondary:
            return Theme.cardShadow().opacity(0.45)
        case .accentTint:
            return Theme.cardShadow()
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .primary:
            return Theme.shadowRadius
        case .secondary:
            return 6
        case .accentTint:
            return Theme.shadowRadius
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .primary:
            return Theme.shadowY
        case .secondary:
            return 3
        case .accentTint:
            return Theme.shadowY
        }
    }
}

extension View {
    func surfaceCard(style: SurfaceCardStyle = .primary, cornerRadius: CGFloat = Theme.radius) -> some View {
        modifier(SurfaceCardModifier(style: style, cornerRadius: cornerRadius))
    }
}
