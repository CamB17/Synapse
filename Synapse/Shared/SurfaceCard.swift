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
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Theme.surface
        case .secondary:
            return Theme.surface2
        case .accentTint:
            return Theme.accent.opacity(0.07)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary:
            return Theme.cardShadow()
        case .secondary:
            return Theme.cardShadow().opacity(0.8)
        case .accentTint:
            return Theme.cardShadow().opacity(0.9)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .primary:
            return 4
        case .secondary:
            return 2.5
        case .accentTint:
            return 3
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .primary:
            return 1.5
        case .secondary:
            return 1
        case .accentTint:
            return 1.5
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Theme.text.opacity(0.08)
        case .secondary:
            return Theme.text.opacity(0.07)
        case .accentTint:
            return Theme.accent.opacity(0.26)
        }
    }
}

extension View {
    func surfaceCard(style: SurfaceCardStyle = .primary, cornerRadius: CGFloat = Theme.radius) -> some View {
        modifier(SurfaceCardModifier(style: style, cornerRadius: cornerRadius))
    }
}
