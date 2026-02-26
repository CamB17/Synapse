import SwiftUI
import UIKit

enum FocusBackgroundTheme: String, CaseIterable, Identifiable {
    case clean
    case night
    case warm
    case cool
    case deepFocus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .clean:
            return "Clean"
        case .night:
            return "Night"
        case .warm:
            return "Warm"
        case .cool:
            return "Cool"
        case .deepFocus:
            return "Deep Focus"
        }
    }

    var tokens: FocusThemeTokens {
        switch self {
        case .clean:
            return FocusThemeTokens(
                base: Theme.surface,
                radialGlow: Theme.accent,
                radialGlowOpacity: 0.11,
                gradientStops: [
                    Theme.surface,
                    Theme.surface2.opacity(0.92),
                    Theme.surface.opacity(0.98)
                ],
                breathingScaleRange: 1.0...1.03,
                breathingOpacityRange: 0.04...0.075,
                textPrimary: Theme.text,
                textSecondary: Theme.textSecondary,
                controlSurface: Theme.surface2.opacity(0.78),
                controlStroke: Theme.textSecondary.opacity(0.16),
                dialTrack: Theme.surface2.opacity(0.95),
                dialProgress: Theme.accent.opacity(0.30),
                dialKnob: Theme.surface,
                dialKnobStroke: Theme.accent.opacity(0.34)
            )
        case .night:
            let base = Color(red: 0.075, green: 0.082, blue: 0.095)
            let soft = base.mixed(with: .black, amount: 0.22)
            return FocusThemeTokens(
                base: base,
                radialGlow: Theme.accent.mixed(with: .white, amount: 0.10),
                radialGlowOpacity: 0.22,
                gradientStops: [
                    base.mixed(with: .black, amount: 0.10),
                    soft,
                    base
                ],
                breathingScaleRange: 1.0...1.04,
                breathingOpacityRange: 0.05...0.09,
                textPrimary: Color(red: 0.94, green: 0.95, blue: 0.98),
                textSecondary: Color(red: 0.75, green: 0.77, blue: 0.84),
                controlSurface: Color.white.opacity(0.09),
                controlStroke: Color.white.opacity(0.20),
                dialTrack: Color.white.opacity(0.13),
                dialProgress: Theme.accent.opacity(0.52),
                dialKnob: Color(red: 0.18, green: 0.19, blue: 0.25),
                dialKnobStroke: Theme.accent.opacity(0.55)
            )
        case .warm:
            let base = Color(red: 0.987, green: 0.958, blue: 0.922)
            return FocusThemeTokens(
                base: base,
                radialGlow: Theme.accent2.mixed(with: Theme.accent, amount: 0.15),
                radialGlowOpacity: 0.12,
                gradientStops: [
                    base,
                    Color(red: 0.972, green: 0.934, blue: 0.888),
                    base
                ],
                breathingScaleRange: 1.0...1.035,
                breathingOpacityRange: 0.045...0.08,
                textPrimary: Theme.text,
                textSecondary: Theme.textSecondary,
                controlSurface: Color.white.opacity(0.60),
                controlStroke: Theme.textSecondary.opacity(0.16),
                dialTrack: Color.white.opacity(0.7),
                dialProgress: Theme.accent2.opacity(0.32),
                dialKnob: Color.white.opacity(0.96),
                dialKnobStroke: Theme.accent2.opacity(0.40)
            )
        case .cool:
            let base = Color(red: 0.93, green: 0.96, blue: 0.99)
            return FocusThemeTokens(
                base: base,
                radialGlow: Theme.accent.mixed(with: Color(red: 0.55, green: 0.75, blue: 1.0), amount: 0.45),
                radialGlowOpacity: 0.13,
                gradientStops: [
                    base,
                    Color(red: 0.90, green: 0.94, blue: 0.985),
                    base
                ],
                breathingScaleRange: 1.0...1.035,
                breathingOpacityRange: 0.045...0.082,
                textPrimary: Theme.text,
                textSecondary: Theme.textSecondary,
                controlSurface: Color.white.opacity(0.62),
                controlStroke: Theme.textSecondary.opacity(0.16),
                dialTrack: Color.white.opacity(0.74),
                dialProgress: Theme.accent.opacity(0.36),
                dialKnob: Color.white.opacity(0.96),
                dialKnobStroke: Theme.accent.opacity(0.42)
            )
        case .deepFocus:
            let base = Color(red: 0.12, green: 0.13, blue: 0.20)
            return FocusThemeTokens(
                base: base,
                radialGlow: Theme.accent.mixed(with: Color(red: 0.35, green: 0.35, blue: 0.6), amount: 0.2),
                radialGlowOpacity: 0.27,
                gradientStops: [
                    base.mixed(with: .black, amount: 0.07),
                    Color(red: 0.10, green: 0.11, blue: 0.18),
                    base
                ],
                breathingScaleRange: 1.0...1.05,
                breathingOpacityRange: 0.06...0.11,
                textPrimary: Color(red: 0.94, green: 0.95, blue: 0.98),
                textSecondary: Color(red: 0.76, green: 0.78, blue: 0.86),
                controlSurface: Color.white.opacity(0.10),
                controlStroke: Color.white.opacity(0.20),
                dialTrack: Color.white.opacity(0.14),
                dialProgress: Theme.accent.opacity(0.56),
                dialKnob: Color(red: 0.21, green: 0.22, blue: 0.30),
                dialKnobStroke: Theme.accent.opacity(0.60)
            )
        }
    }
}

struct FocusThemeTokens {
    let base: Color
    let radialGlow: Color
    let radialGlowOpacity: Double
    let gradientStops: [Color]
    let breathingScaleRange: ClosedRange<CGFloat>
    let breathingOpacityRange: ClosedRange<Double>

    let textPrimary: Color
    let textSecondary: Color
    let controlSurface: Color
    let controlStroke: Color

    let dialTrack: Color
    let dialProgress: Color
    let dialKnob: Color
    let dialKnobStroke: Color
}

private extension Color {
    func mixed(with other: Color, amount: Double) -> Color {
        let clampedAmount = max(0, min(1, amount))
        let left = UIColor(self).rgbaComponents
        let right = UIColor(other).rgbaComponents

        let red = (left.r * (1 - clampedAmount)) + (right.r * clampedAmount)
        let green = (left.g * (1 - clampedAmount)) + (right.g * clampedAmount)
        let blue = (left.b * (1 - clampedAmount)) + (right.b * clampedAmount)
        let alpha = (left.a * (1 - clampedAmount)) + (right.a * clampedAmount)

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

private extension UIColor {
    var rgbaComponents: (r: Double, g: Double, b: Double, a: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (Double(red), Double(green), Double(blue), Double(alpha))
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return (Double(white), Double(white), Double(white), Double(alpha))
        }

        return (0, 0, 0, 1)
    }
}
