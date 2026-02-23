import SwiftUI

enum Theme {
    // MARK: - Core Palette (Light-first)
    static func canvas(for day: Date = .now) -> Color {
        let tone = dayTone(for: day)
        return Color(
            red: clamp(0.97 + (tone.warm * 0.006) - (tone.cool * 0.002)),
            green: clamp(0.96 + (tone.warm * 0.003) + (tone.cool * 0.003)),
            blue: clamp(0.94 - (tone.warm * 0.004) + (tone.cool * 0.004))
        )
    }
    static let surface = Color.white
    static let surface2 = Color(red: 0.992, green: 0.988, blue: 0.982)

    static let text = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let textSecondary = Color(red: 0.45, green: 0.44, blue: 0.47)

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
    
    static func topDepthGradient(for day: Date = .now) -> LinearGradient {
        let tone = dayTone(for: day)
        return LinearGradient(
            colors: [
                Color(
                    red: clamp(0.93 + (tone.cool * 0.010)),
                    green: clamp(0.90 + (tone.warm * 0.004)),
                    blue: clamp(1.00 - (tone.warm * 0.008))
                ).opacity(0.53),
                Color(
                    red: clamp(0.98 + (tone.warm * 0.003)),
                    green: clamp(0.94 + (tone.warm * 0.004)),
                    blue: clamp(0.91 + (tone.cool * 0.006))
                ).opacity(0.40),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func dayTone(for day: Date) -> (warm: Double, cool: Double) {
        let calendar = Calendar.current
        let ordinal = calendar.ordinality(of: .day, in: .year, for: day) ?? 1
        let base = Double(ordinal)
        let warm = sin(base * 0.29)
        let cool = cos(base * 0.23)
        return (warm, cool)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    // MARK: - Layout Tokens
    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 12

    static func cardShadow() -> Color { .black.opacity(0.04) }
    static let shadowRadius: CGFloat = 10
    static let shadowY: CGFloat = 4

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let compact: CGFloat = 6
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let cardInset: CGFloat = 14
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let chipX: CGFloat = 9
        static let chipY: CGFloat = 5
        static let hairline: CGFloat = 1
    }

    enum Typography {
        static let titleLarge = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let titleMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let timerDisplay = Font.system(size: 52, weight: .semibold, design: .rounded)
        static let heroValue = Font.system(size: 40, weight: .semibold, design: .rounded)
        static let heroDenominator = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let sectionLabel = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let sectionTracking: CGFloat = 0.3
        static let chipLabel = Font.system(size: 11, weight: .semibold, design: .rounded)
        static let iconSmall = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let iconMedium = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let iconCompact = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let iconCard = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let iconLarge = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let iconXL = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let itemTitle = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let itemTitleCompact = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let itemTitleProminent = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let tileValue = Font.system(size: 19, weight: .semibold, design: .rounded)
        static let bodyMedium = Font.system(size: 15, weight: .medium, design: .rounded)
        static let bodySmall = Font.system(size: 13, weight: .medium, design: .rounded)
        static let bodySmallStrong = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let labelSmallStrong = Font.system(size: 13, weight: .semibold, design: .rounded)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
        static let panelTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let statValue = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let chipTracking: CGFloat = 0.7
    }
}
