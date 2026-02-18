import SwiftUI
import SwiftData
import Charts

struct ReviewView: View {

    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .forward)])
    private var sessions: [FocusSession]

    @Query(sort: [SortDescriptor(\TaskItem.completedAt, order: .forward)])
    private var tasks: [TaskItem]

    @Query private var habits: [Habit]

    private var calendar: Calendar { .current }

    // MARK: - Calendar Week (Mon–Sun)
    private var weekRange: DateInterval {
        let now = Date()
        let weekOfYear = calendar.component(.weekOfYear, from: now)
        let yearForWeek = calendar.component(.yearForWeekOfYear, from: now)

        var components = DateComponents()
        components.calendar = calendar
        components.yearForWeekOfYear = yearForWeek
        components.weekOfYear = weekOfYear
        components.weekday = 2

        let start = calendar.date(from: components)!

        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        return DateInterval(start: start, end: end)
    }

    private var weekSessions: [FocusSession] {
        sessions.filter { weekRange.contains($0.startedAt) }
    }

    // Robust duration: handles old sessions with durationSeconds = 0
    private func sessionSeconds(_ s: FocusSession) -> Int {
        if s.durationSeconds > 0 { return s.durationSeconds }
        if let end = s.endedAt {
            let delta = Int(end.timeIntervalSince(s.startedAt))
            return max(0, delta)
        }
        return 0
    }

    private var focusSecondsThisWeek: Int {
        weekSessions.reduce(0) { $0 + sessionSeconds($1) }
    }

    private var sessionsCountThisWeek: Int {
        weekSessions.filter { sessionSeconds($0) > 0 }.count
    }

    private var tasksClearedThisWeek: Int {
        tasks.filter {
            $0.state == .completed &&
            ($0.completedAt.map { weekRange.contains($0) } ?? false)
        }.count
    }

    private var habitDaysThisWeek: Int {
        let dates = habits.compactMap { $0.lastCompletedDate }
            .filter { weekRange.contains($0) }
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        return uniqueDays.count
    }

    // MARK: - Daily Focus (Mon..Sun)
    struct DayFocus: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Int
    }

    private var dailyFocus: [DayFocus] {
        (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: weekRange.start)!
            let next = calendar.date(byAdding: .day, value: 1, to: day)!

            let mins = sessions
                .filter { $0.startedAt >= day && $0.startedAt < next }
                .reduce(0) { $0 + sessionSeconds($1) } / 60

            return DayFocus(date: day, minutes: mins)
        }
    }

    private var bestDay: DayFocus? {
        let best = dailyFocus.max(by: { $0.minutes < $1.minutes })
        guard let best, best.minutes > 0 else { return nil }
        return best
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {

                        header

                        focusChartCard

                        kpiGrid

                        highlightsCard

                        Spacer(minLength: Theme.Spacing.lg)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Review")
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    // MARK: - UI

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("This Week")
                .font(Theme.Typography.titleLarge)
                .foregroundStyle(Theme.text)

            Text(formattedWeekRange())
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, Theme.Spacing.compact)
    }

    private var focusChartCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(icon: "timer", title: "Focus")

                Spacer()

                Text(formatFocusFromSeconds(focusSecondsThisWeek))
                    .font(Theme.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
            }

            Chart(dailyFocus) { item in
                let isBest = bestDay.map { $0.minutes > 0 && isSameDay($0.date, item.date) } ?? false

                BarMark(
                    x: .value("Day", shortWeekday(item.date)),
                    y: .value("Minutes", item.minutes)
                )
                .cornerRadius(4)
                .opacity(isBest ? 1.0 : (item.minutes == 0 ? 0.18 : 0.55))
                .foregroundStyle(isBest ? Theme.accent2 : Theme.accent)

                if isBest {
                    PointMark(
                        x: .value("Day", shortWeekday(item.date)),
                        y: .value("Minutes", item.minutes)
                    )
                    .symbolSize(30)
                    .opacity(0.9)
                    .foregroundStyle(Theme.accent2)
                }
            }
            .chartYScale(domain: 0...(max(dailyFocus.map(\.minutes).max() ?? 0, 10)))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: dailyFocus.map { shortWeekday($0.date) }) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: 140)

            if let bestDay {
                Text("Peak: \(weekday(bestDay.date))")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Theme.Spacing.xxs)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard()
    }

    private var kpiGrid: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                kpiCard(value: formatFocusFromSeconds(focusSecondsThisWeek), label: "Focus Time")
                kpiCard(value: "\(sessionsCountThisWeek)", label: "Sessions")
            }
            HStack(spacing: Theme.Spacing.sm) {
                kpiCard(value: "\(tasksClearedThisWeek)", label: "Tasks Cleared")
                kpiCard(value: "\(habitDaysThisWeek) / 7", label: "Habit Days")
            }
        }
    }

    private func kpiCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Typography.statValue)
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())

            Text(label)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let bestDay {
                HStack(spacing: Theme.Spacing.xs) {
                    ZStack(alignment: .topTrailing) {
                        StatusChip(text: "Best day", icon: "star.fill", tone: .accent2)
                        SparkleOverlay()
                    }
                    Spacer(minLength: 0)
                }

                Text("Best day: \(weekday(bestDay.date)) — \(formatMinutes(bestDay.minutes))")
                    .font(Theme.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(Theme.text)
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Illustration(symbol: "chart.bar", style: .line, size: 28)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            SectionLabel(icon: "sparkles", title: "Highlights")

                            Text("No focus logged yet this week.")
                                .font(Theme.Typography.itemTitle)
                                .foregroundStyle(Theme.text)
                        }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard()
    }

    // MARK: - Formatting

    private func formattedWeekRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekRange.start)
        let end = formatter.string(from: calendar.date(byAdding: .day, value: -1, to: weekRange.end)!)
        return "\(start) – \(end)"
    }

    private func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f.string(from: date)
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return "\(h)h \(m)m"
    }
    
    private func formatFocusFromSeconds(_ seconds: Int) -> String {
        if seconds <= 0 { return "0m" }
        if seconds < 60 { return "<1m" }
        return formatMinutes(seconds / 60)
    }
}
