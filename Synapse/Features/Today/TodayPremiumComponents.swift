import SwiftUI
import UIKit

enum TodayPremiumTokens {
    static let pageHorizontalPadding: CGFloat = 22
    static let sectionSpacing: CGFloat = 24
    static let cardCornerRadius: CGFloat = 24
    static let tileCornerRadius: CGFloat = 18
    static let chipCornerRadius: CGFloat = 999
    static let cardPadding: CGFloat = 20
    static let tilePadding: CGFloat = 16
    static let chipHeight: CGFloat = 38
    static let minTapHeight: CGFloat = 44
    static let gridSpacing: CGFloat = 14
}

private enum TodayHaptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct PremiumCardModifier: ViewModifier {
    var cornerRadius: CGFloat = TodayPremiumTokens.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Theme.surface.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

private struct PremiumTileModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface.opacity(0.80))
            .clipShape(RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TodayPremiumTokens.tileCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }
}

extension View {
    func premiumCard(cornerRadius: CGFloat = TodayPremiumTokens.cardCornerRadius) -> some View {
        modifier(PremiumCardModifier(cornerRadius: cornerRadius))
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

struct TodayBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sparklesActive = false

    private let sparkles: [SparkleSeed] = [
        .init(x: 0.18, y: 0.12, size: 4, minOpacity: 0.10, maxOpacity: 0.24, duration: 4.8, delay: 0.0),
        .init(x: 0.36, y: 0.18, size: 3, minOpacity: 0.08, maxOpacity: 0.22, duration: 5.4, delay: 0.6),
        .init(x: 0.74, y: 0.14, size: 3, minOpacity: 0.10, maxOpacity: 0.26, duration: 4.2, delay: 1.0),
        .init(x: 0.84, y: 0.24, size: 5, minOpacity: 0.10, maxOpacity: 0.22, duration: 5.2, delay: 0.3),
        .init(x: 0.12, y: 0.36, size: 2, minOpacity: 0.08, maxOpacity: 0.20, duration: 4.6, delay: 1.4),
        .init(x: 0.62, y: 0.40, size: 4, minOpacity: 0.08, maxOpacity: 0.18, duration: 5.8, delay: 1.1),
        .init(x: 0.82, y: 0.52, size: 3, minOpacity: 0.08, maxOpacity: 0.18, duration: 4.9, delay: 0.4),
        .init(x: 0.24, y: 0.58, size: 4, minOpacity: 0.10, maxOpacity: 0.24, duration: 5.1, delay: 0.9),
        .init(x: 0.52, y: 0.66, size: 3, minOpacity: 0.10, maxOpacity: 0.22, duration: 4.4, delay: 1.5),
        .init(x: 0.90, y: 0.70, size: 2, minOpacity: 0.06, maxOpacity: 0.14, duration: 6.2, delay: 1.8)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.92, blue: 0.99),
                        Color(red: 0.99, green: 0.96, blue: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Ellipse()
                    .fill(Color(red: 0.76, green: 0.72, blue: 0.98).opacity(0.25))
                    .frame(width: proxy.size.width * 1.15, height: 190)
                    .blur(radius: 40)
                    .offset(y: proxy.size.height * 0.20)

                Ellipse()
                    .fill(Color(red: 0.79, green: 0.76, blue: 0.98).opacity(0.23))
                    .frame(width: proxy.size.width * 1.20, height: 220)
                    .blur(radius: 44)
                    .offset(y: proxy.size.height * 0.45)

                Ellipse()
                    .fill(Color(red: 0.88, green: 0.85, blue: 0.99).opacity(0.18))
                    .frame(width: proxy.size.width * 1.1, height: 210)
                    .blur(radius: 40)
                    .offset(y: proxy.size.height * 0.70)

                ForEach(sparkles) { sparkle in
                    Circle()
                        .fill(Color.white)
                        .frame(width: sparkle.size, height: sparkle.size)
                        .position(
                            x: proxy.size.width * sparkle.x,
                            y: proxy.size.height * sparkle.y
                        )
                        .opacity(reduceMotion ? sparkle.minOpacity : (sparklesActive ? sparkle.maxOpacity : sparkle.minOpacity))
                        .blur(radius: sparkle.size > 3 ? 0.4 : 0)
                        .animation(
                            reduceMotion ? .linear(duration: 0) : .easeInOut(duration: sparkle.duration)
                                .repeatForever(autoreverses: true)
                                .delay(sparkle.delay),
                            value: sparklesActive
                        )
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                sparklesActive = true
            }
        }
        .ignoresSafeArea()
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

struct TodayGreetingHeader: View {
    let greeting: String
    let dayContext: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let dayContext {
                Text(dayContext)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary.opacity(0.82))
            }

            Text(greeting)
                .font(.system(size: 37, weight: .semibold, design: .serif))
                .lineSpacing(3)
                .foregroundStyle(Theme.text)

            Text("What's next matters most")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary.opacity(0.90))
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                                isMonthExpanded ? Theme.accent.opacity(0.32) : Theme.textSecondary.opacity(0.14),
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
                            .foregroundStyle(canNavigateToPreviousMonth ? Theme.textSecondary : Theme.textSecondary.opacity(0.42))
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
                            .foregroundStyle(canNavigateToNextMonth ? Theme.textSecondary : Theme.textSecondary.opacity(0.42))
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
                            TodayHaptics.light()
                            onSelectWeekDay(item.date)
                        } label: {
                            VStack(spacing: 3) {
                                Text(item.weekdaySymbol)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(item.isSelected ? Theme.accent : Theme.textSecondary)

                                Text(item.dayNumber)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(item.isSelected ? Theme.accent : Theme.text)

                                Circle()
                                    .fill(item.isComplete ? Theme.accent : .clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .opacity(item.isFuture ? 0.65 : 1)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(item.isSelected ? Theme.accent.opacity(0.12) : Theme.surface.opacity(0.64))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        item.isSelected
                                            ? Theme.accent.opacity(0.62)
                                            : (item.isToday ? Theme.accent.opacity(0.28) : Theme.textSecondary.opacity(0.12)),
                                        lineWidth: item.isSelected ? 1.1 : 0.8
                                    )
                            }
                        }
                        .buttonStyle(TodayPressableButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                }

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
        .premiumCard()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(summaryLine)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Theme.surface2.opacity(0.55))
                    .frame(height: 15)

                GeometryReader { proxy in
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accent2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, proxy.size.width * habitsProgress), height: 15)
                }
            }
            .frame(height: 15)
            .overlay {
                if showCompletionPulse {
                    Capsule(style: .continuous)
                        .stroke(Theme.accent.opacity(0.38), lineWidth: 1)
                        .shadow(color: Theme.accent.opacity(0.25), radius: 10)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: habitsProgress)

            if items.isEmpty {
                Text("No habits yet")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(items.prefix(4)) { item in
                        Button {
                            TodayHaptics.light()
                            onToggleHabit(item.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(item.isComplete ? Theme.accent : Theme.textSecondary)

                                Text(item.title)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Text(item.isComplete ? "Done" : "Open")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: TodayPremiumTokens.minTapHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.surface.opacity(0.66))
                            )
                        }
                        .buttonStyle(TodayPressableButtonStyle())
                    }
                }
            }

            HStack(spacing: 10) {
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
                    .padding(.horizontal, 14)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.surface.opacity(0.72), in: Capsule(style: .continuous))
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
                    .padding(.horizontal, 14)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())

                Spacer(minLength: 0)
            }
        }
        .padding(TodayPremiumTokens.cardPadding)
        .premiumCard()
    }

    private var summaryLine: String {
        if totalActiveHabitsCount == 0 {
            return "Habits: none yet"
        }
        return "Habits: \(completedHabitsCount)/\(totalActiveHabitsCount) complete"
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
                Text(totalCount == 0 ? "Appointments" : "Appointments · \(totalCount)")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)

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
                    .padding(.horizontal, 12)
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
                            Image(systemName: "clock.badge.checkmark")
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
                            .fill(Theme.surface.opacity(0.62))
                    )
                }
                .buttonStyle(TodayPressableButtonStyle())
            }

            if items.isEmpty {
                Text("Nothing scheduled")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
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
                                    .fill(Theme.surface.opacity(0.62))
                            )
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
        .premiumCard()
    }
}

struct TasksSectionHeader: View {
    let timeOfDayLabel: String
    let symbolName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary.opacity(0.9))

            Text("Now: \(timeOfDayLabel)")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}

struct TimeOfDayChipsRow: View {
    let options: [String]
    let selectedOption: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    TodayHaptics.light()
                    onSelect(option)
                } label: {
                    Text(option)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(option == selectedOption ? Theme.accent : Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                        .frame(height: TodayPremiumTokens.chipHeight)
                        .background(
                            Capsule(style: .continuous)
                                .fill(option == selectedOption ? Theme.accent.opacity(0.14) : Theme.surface.opacity(0.72))
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    option == selectedOption ? Theme.accent.opacity(0.44) : Theme.textSecondary.opacity(0.14),
                                    lineWidth: 1
                                )
                        }
                        .shadow(
                            color: option == selectedOption ? Theme.accent.opacity(0.12) : .clear,
                            radius: 4,
                            y: 2
                        )
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
    let upNextSubtitle: String?
    let upNextEstimate: String?
    let tasks: [TodayTaskListItem]
    let emptyStateText: String
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
                    .padding(.horizontal, 12)
                    .frame(minHeight: TodayPremiumTokens.minTapHeight)
                    .background(Theme.surface.opacity(0.72), in: Capsule(style: .continuous))
                }
                .buttonStyle(TodayPressableButtonStyle())
            }

            if let upNextSubtitle {
                Button {
                    TodayHaptics.light()
                    onViewAll()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.accent.opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: "clock")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Up next")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Text(upNextSubtitle)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if let upNextEstimate {
                            Text(upNextEstimate)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textSecondary.opacity(0.88))
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.surface.opacity(0.64))
                    )
                }
                .buttonStyle(TodayPressableButtonStyle())
            }

            if tasks.isEmpty {
                Text(emptyStateText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(2)

                                    if let subtitle = task.subtitle {
                                        Text(subtitle)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(TodayPressableButtonStyle())

                            if let minutesLabel = task.minutesLabel {
                                Text(minutesLabel)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textSecondary.opacity(0.90))
                            }

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
                        .padding(.horizontal, 4)
                        .frame(minHeight: 64)

                        if index < tasks.count - 1 {
                            Rectangle()
                                .fill(Theme.textSecondary.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.surface.opacity(0.60))
                )
            }
        }
        .padding(TodayPremiumTokens.cardPadding)
        .premiumCard()
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
            .premiumCard(cornerRadius: 22)
        }
        .buttonStyle(TodayPressableButtonStyle())
    }
}
