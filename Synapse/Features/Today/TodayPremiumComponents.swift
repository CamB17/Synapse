import SwiftUI
import UIKit

enum TodayPremiumTokens {
    static let pageHorizontalPadding: CGFloat = 22
    static let pageTopPadding: CGFloat = 14
    static let pageBottomPadding: CGFloat = 120
    static let sectionSpacing: CGFloat = 22

    static let cardCornerRadius: CGFloat = 26
    static let tileCornerRadius: CGFloat = 18
    static let chipCornerRadius: CGFloat = 999
    static let cardPadding: CGFloat = 18
    static let innerRowSpacing: CGFloat = 12
    static let chipHeight: CGFloat = 39
    static let minTapHeight: CGFloat = 44
    static let gridSpacing: CGFloat = 12
}

private enum TodayHaptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

struct PremiumGlassCard: ViewModifier {
    var cornerRadius: CGFloat = TodayPremiumTokens.cardCornerRadius

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathingShadow = false

    func body(content: Content) -> some View {
        let shadowOpacity = reduceMotion ? 0.05 : (breathingShadow ? 0.06 : 0.04)

        content
            .background(.ultraThinMaterial)
            .background(Theme.surface.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.52)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 18, x: 0, y: 10)
            .onAppear {
                refreshBreathing()
            }
            .onChange(of: reduceMotion) { _, _ in
                refreshBreathing()
            }
    }

    private func refreshBreathing() {
        guard !reduceMotion else {
            withAnimation(.none) {
                breathingShadow = false
            }
            return
        }

        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
            breathingShadow = true
        }
    }
}

private struct PremiumTileModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }
}

extension View {
    func premiumGlassCard(cornerRadius: CGFloat = TodayPremiumTokens.cardCornerRadius) -> some View {
        modifier(PremiumGlassCard(cornerRadius: cornerRadius))
    }

    // Backwards-compatible alias used by existing Today views.
    func premiumCard(cornerRadius: CGFloat = TodayPremiumTokens.cardCornerRadius) -> some View {
        premiumGlassCard(cornerRadius: cornerRadius)
    }

    func premiumTile() -> some View {
        modifier(PremiumTileModifier())
    }
}

struct TodayPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TodayAtmosphereBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false
    @State private var twinkling = false

    private let blobs: [AtmosphereBlob] = [
        .init(x: 0.10, y: 0.16, width: 460, height: 240, opacity: 0.17, blur: 46, tint: Color(red: 0.78, green: 0.70, blue: 0.97), weight: 1.0),
        .init(x: 0.84, y: 0.30, width: 360, height: 220, opacity: 0.13, blur: 40, tint: Color(red: 0.97, green: 0.81, blue: 0.76), weight: 0.7),
        .init(x: 0.54, y: 0.72, width: 420, height: 260, opacity: 0.12, blur: 48, tint: Color(red: 0.74, green: 0.83, blue: 0.98), weight: 1.2)
    ]

    private let sparkles: [SparkleSeed] = [
        .init(x: 0.12, y: 0.14, size: 1.5, minOpacity: 0.08, maxOpacity: 0.16, duration: 4.8, delay: 0.0),
        .init(x: 0.22, y: 0.20, size: 2.0, minOpacity: 0.08, maxOpacity: 0.18, duration: 5.5, delay: 1.0),
        .init(x: 0.34, y: 0.12, size: 2.0, minOpacity: 0.08, maxOpacity: 0.17, duration: 6.0, delay: 0.6),
        .init(x: 0.44, y: 0.19, size: 1.2, minOpacity: 0.08, maxOpacity: 0.14, duration: 4.4, delay: 0.3),
        .init(x: 0.58, y: 0.14, size: 2.4, minOpacity: 0.09, maxOpacity: 0.18, duration: 5.8, delay: 1.2),
        .init(x: 0.70, y: 0.19, size: 1.4, minOpacity: 0.08, maxOpacity: 0.15, duration: 4.7, delay: 0.5),
        .init(x: 0.82, y: 0.13, size: 2.1, minOpacity: 0.09, maxOpacity: 0.17, duration: 5.0, delay: 0.8),
        .init(x: 0.90, y: 0.25, size: 1.4, minOpacity: 0.08, maxOpacity: 0.14, duration: 5.1, delay: 0.1),
        .init(x: 0.16, y: 0.42, size: 2.6, minOpacity: 0.08, maxOpacity: 0.16, duration: 6.3, delay: 1.5),
        .init(x: 0.30, y: 0.54, size: 1.8, minOpacity: 0.08, maxOpacity: 0.16, duration: 5.3, delay: 0.8),
        .init(x: 0.48, y: 0.66, size: 2.3, minOpacity: 0.08, maxOpacity: 0.18, duration: 4.9, delay: 0.4),
        .init(x: 0.60, y: 0.58, size: 1.6, minOpacity: 0.08, maxOpacity: 0.15, duration: 5.9, delay: 1.1),
        .init(x: 0.76, y: 0.70, size: 2.2, minOpacity: 0.09, maxOpacity: 0.18, duration: 4.6, delay: 0.7),
        .init(x: 0.88, y: 0.62, size: 1.5, minOpacity: 0.08, maxOpacity: 0.14, duration: 6.2, delay: 1.7)
    ]

    var body: some View {
        GeometryReader { proxy in
            let driftX: CGFloat = reduceMotion ? 0 : (drifting ? 10 : -8)
            let driftY: CGFloat = reduceMotion ? 0 : (drifting ? -8 : 6)

            ZStack {
                baseGradient
                blobLayer(proxy: proxy, driftX: driftX, driftY: driftY)
                sparkleLayer(proxy: proxy)
            }
            .onAppear {
                refreshAnimationState()
            }
            .onChange(of: reduceMotion) { _, _ in
                refreshAnimationState()
            }
        }
        .ignoresSafeArea()
    }

    private var baseGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.99),
                    Color(red: 0.99, green: 0.97, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func blobLayer(proxy: GeometryProxy, driftX: CGFloat, driftY: CGFloat) -> some View {
        ZStack {
            ForEach(blobs) { blob in
                Ellipse()
                    .fill(blob.tint.opacity(blob.opacity))
                    .frame(
                        width: min(proxy.size.width * 1.2, blob.width),
                        height: blob.height
                    )
                    .blur(radius: blob.blur)
                    .offset(
                        x: (proxy.size.width * blob.x) - (proxy.size.width * 0.5) + (driftX * blob.weight),
                        y: (proxy.size.height * blob.y) - (proxy.size.height * 0.5) + (driftY * blob.weight)
                    )
            }
        }
        .animation(
            reduceMotion
                ? .linear(duration: 0)
                : .easeInOut(duration: 15).repeatForever(autoreverses: true),
            value: drifting
        )
    }

    private func sparkleLayer(proxy: GeometryProxy) -> some View {
        ZStack {
            ForEach(sparkles) { sparkle in
                Circle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: sparkle.size, height: sparkle.size)
                    .position(
                        x: proxy.size.width * sparkle.x,
                        y: proxy.size.height * sparkle.y
                    )
                    .opacity(
                        reduceMotion
                            ? sparkle.minOpacity
                            : (twinkling ? sparkle.maxOpacity : sparkle.minOpacity)
                    )
                    .blur(radius: sparkle.size > 2 ? 0.35 : 0)
                    .animation(
                        reduceMotion
                            ? .linear(duration: 0)
                            : .easeInOut(duration: sparkle.duration)
                                .repeatForever(autoreverses: true)
                                .delay(sparkle.delay),
                        value: twinkling
                    )
            }
        }
    }

    private func refreshAnimationState() {
        guard !reduceMotion else {
            withAnimation(.none) {
                drifting = false
                twinkling = false
            }
            return
        }

        drifting = true
        twinkling = true
    }

    private struct AtmosphereBlob: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let opacity: Double
        let blur: CGFloat
        let tint: Color
        let weight: CGFloat
    }

    private struct SparkleSeed: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let minOpacity: Double
        let maxOpacity: Double
        let duration: Double
        let delay: Double
    }
}

struct TodayBackgroundView: View {
    var body: some View {
        TodayAtmosphereBackground()
    }
}

struct TodayGreetingHeader: View {
    let greeting: String
    let dayContext: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var driftingGlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text((dayContext ?? "Today").uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .kerning(1.1)
                    .foregroundStyle(Theme.textSecondary.opacity(0.76))

                Circle()
                    .fill(Theme.accent.opacity(0.46))
                    .frame(width: 4, height: 4)
            }

            Text(greeting)
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .lineSpacing(3)
                .foregroundStyle(Theme.text)

            HStack(spacing: 6) {
                Text("What's next matters most")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary.opacity(0.88))

                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent.opacity(0.55))
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.20),
                            Theme.accent2.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 220, height: 130)
                .blur(radius: 44)
                .offset(x: driftingGlow ? 8 : -4, y: driftingGlow ? -8 : 6)
                .opacity(0.52)
                .animation(
                    reduceMotion
                        ? .linear(duration: 0)
                        : .easeInOut(duration: 16).repeatForever(autoreverses: true),
                    value: driftingGlow
                )
                .allowsHitTesting(false)
        }
        .onAppear {
            refreshGlow()
        }
        .onChange(of: reduceMotion) { _, _ in
            refreshGlow()
        }
    }

    private func refreshGlow() {
        guard !reduceMotion else {
            withAnimation(.none) {
                driftingGlow = false
            }
            return
        }

        driftingGlow = true
    }
}

struct TodayCalendarWeekDayItem: Identifiable {
    let date: Date
    let weekdaySymbol: String
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
    let isComplete: Bool
    let isFuture: Bool

    var id: Date { date }
}

struct TodayCalendarStripCard<MonthContent: View>: View {
    let monthLabel: String
    let weekItems: [TodayCalendarWeekDayItem]
    let isMonthExpanded: Bool
    let showsBackToToday: Bool
    let showsCurrentMonthShortcut: Bool
    let canNavigateToPreviousMonth: Bool
    let canNavigateToNextMonth: Bool
    let onToggleMonth: () -> Void
    let onSelectWeekDay: (Date) -> Void
    let onBackToTodayTap: () -> Void
    let onCurrentMonthTap: () -> Void
    let onChooseMonthYear: () -> Void
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    @ViewBuilder let monthContent: () -> MonthContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsingDay: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button {
                    TodayHaptics.light()
                    onChooseMonthYear()
                } label: {
                    HStack(spacing: 6) {
                        Text(monthLabel)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: TodayPremiumTokens.minTapHeight)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Theme.surface.opacity(0.7))
                    )
                }
                .buttonStyle(TodayPressableButtonStyle())

                Spacer(minLength: 0)

                Button {
                    TodayHaptics.light()
                    onToggleMonth()
                } label: {
                    HStack(spacing: 6) {
                        Text(isMonthExpanded ? "Week" : "Month")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(isMonthExpanded ? Theme.accent : Theme.textSecondary)

                        Image(systemName: isMonthExpanded ? "calendar" : "calendar.badge.clock")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(isMonthExpanded ? Theme.accent : Theme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: TodayPremiumTokens.minTapHeight)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isMonthExpanded ? Theme.accent.opacity(0.14) : Theme.surface.opacity(0.7))
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                isMonthExpanded ? Theme.accent.opacity(0.34) : Theme.textSecondary.opacity(0.14),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())
            }

            if isMonthExpanded {
                HStack(spacing: 10) {
                    Button {
                        TodayHaptics.light()
                        onPreviousMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                canNavigateToPreviousMonth
                                    ? Theme.textSecondary
                                    : Theme.textSecondary.opacity(0.42)
                            )
                            .frame(width: 32, height: 32)
                            .background(Theme.surface.opacity(0.86), in: Circle())
                    }
                    .buttonStyle(TodayPressableButtonStyle())
                    .disabled(!canNavigateToPreviousMonth)

                    Spacer(minLength: 0)

                    Button {
                        TodayHaptics.light()
                        onChooseMonthYear()
                    } label: {
                        Text(monthLabel)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(TodayPressableButtonStyle())

                    Spacer(minLength: 0)

                    Button {
                        TodayHaptics.light()
                        onNextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                canNavigateToNextMonth
                                    ? Theme.textSecondary
                                    : Theme.textSecondary.opacity(0.42)
                            )
                            .frame(width: 32, height: 32)
                            .background(Theme.surface.opacity(0.86), in: Circle())
                    }
                    .buttonStyle(TodayPressableButtonStyle())
                    .disabled(!canNavigateToNextMonth)
                }

                if showsCurrentMonthShortcut {
                    HStack {
                        Spacer(minLength: 0)

                        Button {
                            TodayHaptics.light()
                            onCurrentMonthTap()
                        } label: {
                            Text("Current month")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(Theme.surface.opacity(0.72), in: Capsule(style: .continuous))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(Theme.textSecondary.opacity(0.14), lineWidth: 1)
                                }
                        }
                        .buttonStyle(TodayPressableButtonStyle())
                    }
                    .transition(.opacity)
                }

                monthContent()
                    .transition(.opacity)
            } else {
                HStack(spacing: 8) {
                    ForEach(weekItems) { item in
                        Button {
                            TodayHaptics.soft()
                            animatePulse(for: item.date)
                            onSelectWeekDay(item.date)
                        } label: {
                            VStack(spacing: 4) {
                                Text(item.weekdaySymbol)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(item.isSelected ? Theme.accent : Theme.textSecondary)

                                Text(item.dayNumber)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(item.isSelected ? Theme.accent : Theme.text)

                                Circle()
                                    .fill(item.isComplete ? Theme.accent.opacity(0.70) : .clear)
                                    .frame(width: 3.5, height: 3.5)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .opacity(item.isFuture ? 0.65 : 1)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(item.isSelected ? Theme.accent.opacity(0.16) : Theme.surface.opacity(0.64))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(
                                        item.isSelected
                                            ? Theme.accent.opacity(0.62)
                                            : (item.isToday ? Theme.accent.opacity(0.32) : Theme.textSecondary.opacity(0.12)),
                                        lineWidth: item.isSelected ? 1.1 : 0.8
                                    )
                            }
                            .shadow(
                                color: item.isSelected ? Theme.accent.opacity(0.16) : .clear,
                                radius: 8,
                                y: 4
                            )
                            .scaleEffect(isPulsing(item.date) ? 0.98 : 1)
                        }
                        .buttonStyle(TodayPressableButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(
                    reduceMotion ? .linear(duration: 0) : .easeOut(duration: 0.12),
                    value: pulsingDay
                )

                if showsBackToToday {
                    HStack {
                        Spacer(minLength: 0)

                        Button {
                            TodayHaptics.light()
                            onBackToTodayTap()
                        } label: {
                            Text("Back to Today")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(Theme.surface.opacity(0.72), in: Capsule(style: .continuous))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(Theme.textSecondary.opacity(0.14), lineWidth: 1)
                                }
                        }
                        .buttonStyle(TodayPressableButtonStyle())
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(TodayPremiumTokens.cardPadding)
        .premiumGlassCard()
    }

    private func animatePulse(for day: Date) {
        guard !reduceMotion else { return }
        pulsingDay = day
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            pulsingDay = nil
        }
    }

    private func isPulsing(_ day: Date) -> Bool {
        guard let pulsingDay else { return false }
        return Calendar.current.isDate(day, inSameDayAs: pulsingDay)
    }
}

struct HabitMomentumItem: Identifiable {
    let id: UUID
    let title: String
    let isComplete: Bool
}

struct HabitMomentumCard: View {
    let completedHabitsCount: Int
    let totalActiveHabitsCount: Int
    let habitsProgress: CGFloat
    let showCompletionPulse: Bool
    let items: [HabitMomentumItem]
    let onToggleHabit: (UUID) -> Void
    let onManageTap: () -> Void
    let onAddHabitTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlightedHabitID: UUID?
    @State private var shimmerVisible = false
    @State private var shimmerProgress: CGFloat = -0.25
    @State private var transientCompletionBadge = false

    private var completionRatio: CGFloat {
        min(1, max(0, habitsProgress))
    }

    private var completionText: String {
        "\(completedHabitsCount)/\(max(totalActiveHabitsCount, 0))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("Habits")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Text(completionText)
                        .contentTransition(.numericText())

                    if totalActiveHabitsCount > 0, completionRatio >= 1 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Theme.accent.opacity(0.14), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Theme.accent.opacity(0.30), lineWidth: 1)
                }
                .overlay(alignment: .trailing) {
                    if transientCompletionBadge {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                            .offset(x: 14)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
            }

            progressBar

            if items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No habits yet")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Add a habit to start your daily rhythm")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surface2.opacity(0.35))
                )
            } else {
                VStack(spacing: TodayPremiumTokens.innerRowSpacing) {
                    ForEach(items.prefix(4)) { item in
                        let isHighlighted = highlightedHabitID == item.id
                        Button {
                            flashRow(for: item.id)
                            onToggleHabit(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(item.isComplete ? Theme.accent : Theme.textSecondary)
                                    .scaleEffect(isHighlighted ? 1.12 : 1)

                                Text(item.title)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Text(item.isComplete ? "Done" : "Open")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary.opacity(0.78))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(minHeight: TodayPremiumTokens.minTapHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        Theme.surface2.opacity(isHighlighted ? 0.52 : 0.35)
                                    )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        isHighlighted
                                            ? Theme.accent.opacity(0.24)
                                            : Color.white.opacity(0.14),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(TodayPressableButtonStyle())
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    TodayHaptics.light()
                    onManageTap()
                } label: {
                    HStack(spacing: 6) {
                        Text("Manage")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.surface.opacity(0.72), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Theme.textSecondary.opacity(0.14), lineWidth: 1)
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())

                Button {
                    TodayHaptics.light()
                    onAddHabitTap()
                } label: {
                    HStack(spacing: 6) {
                        Text("Add habit")
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Theme.accent.opacity(0.30), lineWidth: 1)
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())
            }
        }
        .padding(TodayPremiumTokens.cardPadding)
        .premiumGlassCard()
        .onChange(of: completionRatio) { oldValue, newValue in
            guard totalActiveHabitsCount > 0 else { return }
            guard oldValue < 1, newValue >= 1 else { return }
            triggerCompletionCelebration()
        }
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Theme.surface2.opacity(0.56))
                .frame(height: 14)

            GeometryReader { proxy in
                let fillWidth = max(0, proxy.size.width * completionRatio)
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accent2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 12)

                    Capsule(style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: fillWidth, height: 12)
                        .blur(radius: 9)

                    if shimmerVisible, fillWidth > 20 {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.65),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(42, fillWidth * 0.45), height: 24)
                            .offset(x: (fillWidth + 40) * shimmerProgress - 20)
                            .mask(
                                Capsule(style: .continuous)
                                    .frame(width: fillWidth, height: 12)
                            )
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: completionRatio)
            }
            .frame(height: 14)
        }
        .padding(1)
        .overlay {
            if showCompletionPulse || (totalActiveHabitsCount > 0 && completionRatio >= 1) {
                Capsule(style: .continuous)
                    .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
            }
        }
    }

    private func flashRow(for id: UUID) {
        withAnimation(.easeOut(duration: 0.12)) {
            highlightedHabitID = id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                if highlightedHabitID == id {
                    highlightedHabitID = nil
                }
            }
        }
    }

    private func triggerCompletionCelebration() {
        withAnimation(.easeInOut(duration: 0.14)) {
            transientCompletionBadge = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeInOut(duration: 0.18)) {
                transientCompletionBadge = false
            }
        }

        guard !reduceMotion else { return }

        shimmerProgress = -0.25
        shimmerVisible = true
        withAnimation(.easeInOut(duration: 0.6)) {
            shimmerProgress = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
            shimmerVisible = false
        }
    }
}

struct TodayAppointmentListItem: Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let icon: String
}

struct AppointmentsPreviewCard: View {
    let totalCount: Int
    let upcomingLine: String?
    let items: [TodayAppointmentListItem]
    let remainingCount: Int
    let onTapItem: (UUID) -> Void
    let onViewAll: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Appointments")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)

                if totalCount > 0 {
                    Text("\(totalCount)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Theme.accent.opacity(0.24), lineWidth: 1)
                        }
                }

                Spacer(minLength: 0)

                Button {
                    TodayHaptics.light()
                    onAdd()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text("Add")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Theme.accent.opacity(0.26), lineWidth: 1)
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())

                Button {
                    TodayHaptics.light()
                    onViewAll()
                } label: {
                    HStack(spacing: 4) {
                        Text("View all")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.surface.opacity(0.72), in: Capsule(style: .continuous))
                }
                .buttonStyle(TodayPressableButtonStyle())
            }

            if let upcomingLine {
                Button {
                    TodayHaptics.light()
                    onViewAll()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.accent.opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: "calendar")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Coming up")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary.opacity(0.84))
                            Text(upcomingLine)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary.opacity(0.76))
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 58)
                    .background(
                        RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous)
                            .fill(Theme.surface2.opacity(0.35))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())
            }

            if items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nothing scheduled")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)

                    Text("Add an appointment to stay organized")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)

                    Button {
                        TodayHaptics.light()
                        onAdd()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Text("Add")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Theme.accent.opacity(0.26), lineWidth: 1)
                        }
                    }
                    .buttonStyle(TodayPressableButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous)
                        .fill(Theme.surface2.opacity(0.35))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
            } else {
                VStack(spacing: TodayPremiumTokens.innerRowSpacing) {
                    ForEach(items) { item in
                        Button {
                            TodayHaptics.light()
                            onTapItem(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Theme.accent.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: item.icon)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.accent)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)

                                    Text(item.detail)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 56)
                            .background(
                                RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous)
                                    .fill(Theme.surface2.opacity(0.35))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            }
                        }
                        .buttonStyle(TodayPressableButtonStyle())
                    }
                }

                if remainingCount > 0 {
                    Button {
                        TodayHaptics.light()
                        onViewAll()
                    } label: {
                        HStack(spacing: 6) {
                            Text("+\(remainingCount) more")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: TodayPremiumTokens.minTapHeight)
                        .background(Theme.surface.opacity(0.72), in: Capsule(style: .continuous))
                    }
                    .buttonStyle(TodayPressableButtonStyle())
                }
            }
        }
        .padding(TodayPremiumTokens.cardPadding)
        .premiumGlassCard()
    }
}

struct TasksSectionHeader: View {
    let timeOfDayLabel: String
    let symbolName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary.opacity(0.88))

            Text("Now: \(timeOfDayLabel)")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

struct TimeOfDayChipsRow: View {
    let options: [String]
    let selectedOption: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selectedOption
                Button {
                    TodayHaptics.light()
                    onSelect(option)
                } label: {
                    HStack(spacing: 6) {
                        if isSelected {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 5, height: 5)
                        }

                        Text(option)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: TodayPremiumTokens.chipHeight)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Theme.accent.opacity(0.16) : Theme.surface.opacity(0.72))
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                isSelected ? Theme.accent.opacity(0.44) : Theme.textSecondary.opacity(0.14),
                                lineWidth: isSelected ? 1.1 : 1
                            )
                    }
                    .overlay(alignment: .top) {
                        if isSelected {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.24), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .padding(.horizontal, 1)
                        }
                    }
                    .shadow(color: isSelected ? Theme.accent.opacity(0.12) : .clear, radius: 4, y: 2)
                }
                .buttonStyle(TodayPressableButtonStyle())
            }
        }
    }
}

struct TodayTaskListItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String?
    let minutesLabel: String?
    let icon: String
    let iconTint: Color
}

struct TasksListCard: View {
    let upNextTitle: String?
    let upNextEstimate: String?
    let tasks: [TodayTaskListItem]
    let emptyStateTitle: String
    let emptyStateSubtitle: String
    let onTaskTap: (UUID) -> Void
    let onCompleteTask: (UUID) -> Void
    let onViewAll: () -> Void
    let onQuickAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Tasks")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)

                Spacer(minLength: 0)

                Button {
                    TodayHaptics.light()
                    onQuickAdd()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text("Quick add")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Theme.accent.opacity(0.26), lineWidth: 1)
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())

                Button {
                    TodayHaptics.light()
                    onViewAll()
                } label: {
                    HStack(spacing: 4) {
                        Text("View all")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.surface.opacity(0.72), in: Capsule(style: .continuous))
                }
                .buttonStyle(TodayPressableButtonStyle())
            }

            if let upNextTitle {
                Button {
                    TodayHaptics.light()
                    onViewAll()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.accent.opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: "timer")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Up next")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary.opacity(0.84))
                            Text(upNextTitle)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if let upNextEstimate {
                            Text(upNextEstimate)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textSecondary.opacity(0.88))
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surface2.opacity(0.35))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())
            }

            if tasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(emptyStateTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)

                    Text(emptyStateSubtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)

                    Button {
                        TodayHaptics.light()
                        onQuickAdd()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Text("Quick add")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Theme.accent.opacity(0.26), lineWidth: 1)
                        }
                    }
                    .buttonStyle(TodayPressableButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surface2.opacity(0.35))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
            } else {
                VStack(spacing: TodayPremiumTokens.innerRowSpacing) {
                    ForEach(tasks) { task in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(task.iconTint.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                Image(systemName: task.icon)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(task.iconTint)
                            }

                            Button {
                                TodayHaptics.light()
                                onTaskTap(task.id)
                            } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Theme.text)
                                            .lineLimit(2)

                                        if let subtitle = task.subtitle {
                                            Text(subtitle)
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(Theme.textSecondary.opacity(0.86))
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: 0)

                                    if let minutesLabel = task.minutesLabel {
                                        Text(minutesLabel)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.textSecondary.opacity(0.90))
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.textSecondary.opacity(0.68))
                                }
                            }
                            .buttonStyle(TodayPressableButtonStyle())

                            Button {
                                TodayHaptics.light()
                                onCompleteTask(task.id)
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary.opacity(0.92))
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(TodayPressableButtonStyle())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(minHeight: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.surface2.opacity(0.35))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        }
                    }
                }
            }
        }
        .padding(TodayPremiumTokens.cardPadding)
        .premiumGlassCard()
    }
}

struct FocusEntryCard: View {
    let recommendation: String?
    let onTap: () -> Void

    var body: some View {
        Button {
            TodayHaptics.light()
            onTap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: "person.crop.circle.badge.clock")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }

                Text("Start focus")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer(minLength: 0)

                if let recommendation {
                    Text(recommendation)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
            }
            .padding(TodayPremiumTokens.cardPadding)
            .premiumGlassCard(cornerRadius: 22)
        }
        .buttonStyle(TodayPressableButtonStyle())
    }
}
