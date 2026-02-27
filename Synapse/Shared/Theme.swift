import SwiftUI
import CoreText

enum Theme {
    enum AppFontWeight: String, CaseIterable {
        case regular
        case medium
        case semibold
        case bold
    }

    private static let appFontCandidates: [AppFontWeight: [String]] = [
        .regular: ["Satoshi-Regular"],
        .medium: ["Satoshi-Medium"],
        .semibold: ["Satoshi-Semibold", "Satoshi-Bold", "Satoshi-Medium"],
        .bold: ["Satoshi-Bold"]
    ]
    private static let registeredPostScriptNames: Set<String> = {
        let names = CTFontManagerCopyAvailablePostScriptNames() as? [String] ?? []
        return Set(names)
    }()

    static func resolvedAppFontPostScript(for weight: AppFontWeight) -> String? {
        guard let candidates = appFontCandidates[weight] else { return nil }
        return candidates.first(where: isAppFontAvailable(postScriptName:))
    }

    static func appFont(_ weight: AppFontWeight, size: CGFloat) -> Font {
        if let postScriptName = resolvedAppFontPostScript(for: weight) {
            return .custom(postScriptName, size: size)
        }
        return .system(size: size, weight: systemWeight(for: weight), design: .default)
    }

    private static func systemWeight(for weight: AppFontWeight) -> Font.Weight {
        switch weight {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }

    private static func isAppFontAvailable(postScriptName: String) -> Bool {
        registeredPostScriptNames.contains(postScriptName)
    }

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

    static let text = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let textSecondary = Color(red: 0.34, green: 0.33, blue: 0.37)

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
                ).opacity(0.16),
                Color(
                    red: clamp(0.98 + (tone.warm * 0.003)),
                    green: clamp(0.94 + (tone.warm * 0.004)),
                    blue: clamp(0.91 + (tone.cool * 0.006))
                ).opacity(0.08),
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

    static func cardShadow() -> Color { .black.opacity(0.025) }
    static let shadowRadius: CGFloat = 5
    static let shadowY: CGFloat = 2

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
        // Deliberate hierarchy
        static let heroTitle = Theme.appFont(.semibold, size: 36)
        static let screenTitle = Theme.appFont(.semibold, size: 30)
        static let sectionTitle = Theme.appFont(.semibold, size: 19)
        static let itemTitle = Theme.appFont(.medium, size: 16)
        static let body = Theme.appFont(.regular, size: 15)
        static let labelCaps = Theme.appFont(.medium, size: 12)
        static let labelTracking: CGFloat = 0.8
        static let metricValue = Theme.appFont(.semibold, size: 22)

        // Backwards-compatible tokens used across existing views
        static let titleLarge = Theme.appFont(.semibold, size: 22)
        static let titleMedium = Theme.appFont(.semibold, size: 20)
        static let editorialTitle = Theme.appFont(.semibold, size: 40)
        static let editorialHero = Theme.appFont(.semibold, size: 44)
        static let timerDisplay = Theme.appFont(.semibold, size: 52)
        static let heroValue = Theme.appFont(.semibold, size: 40)
        static let heroDenominator = Theme.appFont(.semibold, size: 20)
        static let sectionLabel = labelCaps
        static let sectionTracking: CGFloat = labelTracking
        static let chipLabel = Theme.appFont(.medium, size: 11)
        static let iconSmall = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let iconMedium = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let iconCompact = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let iconCard = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let iconLarge = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let iconXL = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let itemTitleCompact = Theme.appFont(.medium, size: 16)
        static let itemTitleProminent = Theme.appFont(.semibold, size: 17)
        static let tileValue = metricValue
        static let bodyMedium = Theme.appFont(.medium, size: 15)
        static let bodySmall = Theme.appFont(.regular, size: 13)
        static let bodySmallStrong = Theme.appFont(.semibold, size: 14)
        static let labelSmallStrong = Theme.appFont(.medium, size: 13)
        static let caption = Theme.appFont(.medium, size: 12)
        static let panelTitle = sectionTitle
        static let statValue = metricValue
        static let chipTracking: CGFloat = 0.8
    }
}
