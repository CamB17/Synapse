import SwiftUI

enum Theme {
    // MARK: - Core Palette (Light-first)
    static let canvas = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let surface = Color.white
    static let surface2 = Color(red: 0.98, green: 0.98, blue: 0.99)

    static let text = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let textSecondary = Color(red: 0.40, green: 0.40, blue: 0.46)

    static let accent = Color(red: 0.43, green: 0.35, blue: 0.88)
    static let accent2 = Color(red: 0.96, green: 0.58, blue: 0.50)

    static let success = Color(red: 0.20, green: 0.70, blue: 0.45)

    // MARK: - Gradients
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.89, blue: 1.00),
            Color(red: 0.98, green: 0.92, blue: 0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let focusGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.90, blue: 1.00),
            Color(red: 0.90, green: 0.96, blue: 1.00)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let topDepthGradient = LinearGradient(
        colors: [
            Color(red: 0.93, green: 0.90, blue: 1.00).opacity(0.55),
            Color(red: 0.98, green: 0.94, blue: 0.91).opacity(0.42),
            .clear
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Layout Tokens
    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 14

    static func cardShadow() -> Color { .black.opacity(0.06) }
    static let shadowRadius: CGFloat = 12
    static let shadowY: CGFloat = 6
}
