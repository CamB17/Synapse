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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    header

                    focusChartCard

                    kpiGrid

                    highlightsCard

                    Spacer(minLength: 24)
                }
                .padding(16)
            }
            .navigationTitle("Review")
        }
    }

    // MARK: - UI

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This Week")
                .font(.system(size: 22, weight: .semibold))

            Text(formattedWeekRange())
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }

    private var focusChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Focus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatFocusFromSeconds(focusSecondsThisWeek))
                    .font(.system(size: 16, weight: .semibold))
                    .contentTransition(.numericText())
            }

            Chart(dailyFocus) { item in
                let isBest = (bestDay != nil && bestDay!.minutes > 0 && isSameDay(bestDay!.date, item.date))

                BarMark(
                    x: .value("Day", shortWeekday(item.date)),
                    y: .value("Minutes", item.minutes)
                )
                .cornerRadius(4)
                .opacity(isBest ? 1.0 : (item.minutes == 0 ? 0.18 : 0.55))

                if isBest {
                    PointMark(
                        x: .value("Day", shortWeekday(item.date)),
                        y: .value("Minutes", item.minutes)
                    )
                    .symbolSize(30)
                    .opacity(0.9)
                }
            }
            .chartYScale(domain: 0...(max(dailyFocus.map(\.minutes).max() ?? 0, 10)))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: dailyFocus.map { shortWeekday($0.date) }) { _ in
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 140)

            if let bestDay {
                Text("Peak: \(weekday(bestDay.date))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var kpiGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                kpiCard(value: formatFocusFromSeconds(focusSecondsThisWeek), label: "Focus Time")
                kpiCard(value: "\(sessionsCountThisWeek)", label: "Sessions")
            }
            HStack(spacing: 12) {
                kpiCard(value: "\(tasksClearedThisWeek)", label: "Tasks Cleared")
                kpiCard(value: "\(habitDaysThisWeek) / 7", label: "Habit Days")
            }
        }
    }

    private func kpiCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Highlights")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            if let bestDay {
                Text("Best day: \(weekday(bestDay.date)) — \(formatMinutes(bestDay.minutes))")
                    .font(.system(size: 15, weight: .semibold))
            } else {
                Text("No focus logged yet this week.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
