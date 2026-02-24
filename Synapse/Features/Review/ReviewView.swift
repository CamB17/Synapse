import SwiftUI
import SwiftData

struct ReviewView: View {
    @Query(sort: [SortDescriptor(\TaskItem.createdAt, order: .forward)])
    private var tasks: [TaskItem]

    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .forward)])
    private var sessions: [FocusSession]

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @Query(sort: [SortDescriptor(\HabitCompletion.day, order: .reverse)])
    private var habitCompletions: [HabitCompletion]

    @Query(sort: [SortDescriptor(\HabitPausePeriod.startDay, order: .reverse)])
    private var habitPausePeriods: [HabitPausePeriod]

    @State private var mode: ReviewMode = .daily

    private struct RitualDaySummary {
        let total: Int
        let completed: Int

        var ratio: CGFloat {
            guard total > 0 else { return 0 }
            return CGFloat(completed) / CGFloat(total)
        }

        var isComplete: Bool {
            total > 0 && completed == total
        }
    }

    private enum ReviewMode: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case monthly = "Monthly"

        var id: String { rawValue }
    }

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
    }
    private var monthEnd: Date {
        calendar.date(byAdding: .month, value: 1, to: monthStart) ?? .distantFuture
    }

    private var dailyRitualSummary: RitualDaySummary {
        ritualSummary(for: todayStart)
    }

    private var dailyRitualCompletionValue: String {
        guard dailyRitualSummary.total > 0 else { return "Not set" }
        return "\(dailyRitualSummary.completed) of \(dailyRitualSummary.total)"
    }

    private var dailyRitualConsistency: Int {
        Int((dailyRitualSummary.ratio * 100).rounded())
    }

    private var dailyCompletedTasks: [TaskItem] {
        tasks.filter { task in
            task.state == .completed && calendar.isDate(assignmentDay(for: task), inSameDayAs: todayStart)
        }
    }

    private var dailyFocusSeconds: Int {
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? .distantFuture
        return sessions
            .filter { $0.startedAt >= todayStart && $0.startedAt < end }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    private var dailyTrendDays: [Date] {
        (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: todayStart)
        }
    }

    private var maxDailyTrendRatio: CGFloat {
        max(0.25, dailyTrendDays.map { ritualSummary(for: $0).ratio }.max() ?? 0)
    }

    private var dailyInsightLine: String {
        if dailyRitualSummary.total == 0 {
            return "Add one ritual to begin your daily foundation."
        }
        if dailyRitualSummary.isComplete {
            return "Identity reinforced through consistency."
        }
        if dailyRitualConsistency < 50 {
            return "Protect one ritual first. Momentum follows."
        }
        return "Another steady day of alignment."
    }

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private var weekdaySymbolsOrdered: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var monthRitualSummaries: [Date: RitualDaySummary] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [:] }

        var summaries: [Date: RitualDaySummary] = [:]
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let start = calendar.startOfDay(for: date)
            summaries[start] = ritualSummary(for: start)
        }
        return summaries
    }

    private var monthlyBestStreak: Int {
        let monthDates = monthRitualSummaries.keys.sorted()
        var best = 0
        var run = 0

        for day in monthDates {
            let summary = monthRitualSummaries[day] ?? RitualDaySummary(total: 0, completed: 0)
            if summary.total == 0 {
                continue
            }
            if summary.isComplete {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }

        return best
    }

    private var monthlyAverageConsistencyPercent: Int {
        let values = monthRitualSummaries.values.compactMap { summary -> Double? in
            guard summary.total > 0 else { return nil }
            return Double(summary.completed) / Double(summary.total)
        }

        guard !values.isEmpty else { return 0 }
        let avg = values.reduce(0, +) / Double(values.count)
        return Int((avg * 100).rounded())
    }

    private var monthlyWeekdayStrength: (strongest: String, weakest: String)? {
        let groupedByWeekday = Dictionary(grouping: monthRitualSummaries) { entry in
            calendar.component(.weekday, from: entry.key)
        }

        let averages: [(weekday: Int, score: Double)] = groupedByWeekday.compactMap { weekday, entries in
            let values = entries.compactMap { _, summary -> Double? in
                guard summary.total > 0 else { return nil }
                return Double(summary.completed) / Double(summary.total)
            }
            guard !values.isEmpty else { return nil }
            let average = values.reduce(0, +) / Double(values.count)
            return (weekday, average)
        }

        guard let strongest = averages.max(by: { $0.score < $1.score }),
              let weakest = averages.min(by: { $0.score < $1.score }) else {
            return nil
        }

        let strongestName = calendar.weekdaySymbols[max(0, min(calendar.weekdaySymbols.count - 1, strongest.weekday - 1))]
        let weakestName = calendar.weekdaySymbols[max(0, min(calendar.weekdaySymbols.count - 1, weakest.weekday - 1))]
        return (strongestName, weakestName)
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        modePicker

                        switch mode {
                        case .daily:
                            dailyReview
                        case .monthly:
                            monthlyReview
                        }

                        Spacer(minLength: Theme.Spacing.lg)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Review")
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private var modePicker: some View {
        Picker("Review mode", selection: $mode) {
            ForEach(ReviewMode.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var dailyReview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Rituals")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)

                dailyTrendStrip

                metricRow(label: "Ritual completion", value: dailyRitualCompletionValue)
                metricRow(label: "Consistency", value: "\(dailyRitualConsistency)%")

                Text(dailyInsightLine)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.cardInset)
            .surfaceCard()

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Support")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.88))

                metricRow(
                    label: "Tasks completed",
                    value: "\(dailyCompletedTasks.count)",
                    valueColor: Theme.textSecondary.opacity(0.9)
                )
                metricRow(
                    label: "Focus minutes",
                    value: formatMinutes(dailyFocusSeconds),
                    valueColor: Theme.textSecondary.opacity(0.9)
                )
            }
            .padding(Theme.Spacing.cardInset)
            .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
        }
    }

    private var dailyTrendStrip: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xxs) {
            ForEach(dailyTrendDays, id: \.self) { day in
                let ratio = ritualSummary(for: day).ratio
                let normalized = ratio / maxDailyTrendRatio

                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(Theme.accent.opacity(ratio == 0 ? 0.1 : 0.2 + (0.35 * normalized)))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6 + (18 * normalized))
                    .overlay(alignment: .bottom) {
                        if calendar.isDateInToday(day) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .stroke(Theme.accent.opacity(0.5), lineWidth: 0.8)
                        }
                    }
            }
        }
        .frame(height: 26)
        .padding(.bottom, Theme.Spacing.xxs)
    }

    private var monthlyReview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(monthStart.formatted(.dateTime.month(.wide).year()))
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            monthHeatmap

            metricRow(label: "Best streak", value: "\(monthlyBestStreak) day\(monthlyBestStreak == 1 ? "" : "s")")
            metricRow(label: "Average consistency", value: "\(monthlyAverageConsistencyPercent)%")

            if let weekdayStrength = monthlyWeekdayStrength {
                metricRow(label: "Strongest weekday", value: weekdayStrength.strongest)
                metricRow(label: "Weakest weekday", value: weekdayStrength.weakest)
            } else {
                Text("Not enough monthly data yet.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard()
    }

    private var monthHeatmap: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xxs), count: 7), spacing: Theme.Spacing.xxs) {
                ForEach(weekdaySymbolsOrdered, id: \.self) { symbol in
                    Text(symbol)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        heatmapCell(for: day)
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                Text("Less")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: Theme.Spacing.xxs) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.accent.opacity(0.12 + (CGFloat(index) * 0.2)))
                            .frame(width: 18, height: 10)
                    }
                }

                Text("More")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func heatmapCell(for day: Date) -> some View {
        let summary = monthRitualSummaries[calendar.startOfDay(for: day), default: RitualDaySummary(total: 0, completed: 0)]
        let ratio = summary.ratio

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(summary.total == 0 ? Theme.surface2 : Theme.accent.opacity(0.12 + (0.58 * ratio)))

            Text(day.formatted(.dateTime.day()))
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.text)
        }
        .frame(height: 32)
    }

    private func metricRow(label: String, value: String, valueColor: Color = Theme.text) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Spacer(minLength: 0)

            Text(value)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
        }
    }

    private func ritualSummary(for day: Date) -> RitualDaySummary {
        let target = calendar.startOfDay(for: day)
        let activeForDay = habits.filter { isHabit($0, activeOn: target) }
        guard !activeForDay.isEmpty else { return RitualDaySummary(total: 0, completed: 0) }

        let completedIDs = Set(
            habitCompletions
                .filter { calendar.isDate($0.day, inSameDayAs: target) }
                .map(\.habitId)
        )
        let completedCount = activeForDay.reduce(0) { partial, habit in
            partial + (completedIDs.contains(habit.id) ? 1 : 0)
        }
        return RitualDaySummary(total: activeForDay.count, completed: completedCount)
    }

    private func isHabit(_ habit: Habit, activeOn day: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let createdDay = calendar.startOfDay(for: habit.createdAt)
        guard dayStart >= createdDay else { return false }

        let periods = habitPausePeriods.filter { $0.habitId == habit.id }
        if !habit.isActive, periods.allSatisfy({ $0.endDay != nil }), dayStart >= todayStart {
            return false
        }
        for period in periods {
            let start = calendar.startOfDay(for: period.startDay)
            let end = calendar.startOfDay(for: period.endDay ?? .distantFuture)
            if dayStart >= start && dayStart < end {
                return false
            }
        }
        return true
    }

    private func assignmentDay(for task: TaskItem) -> Date {
        if let assigned = task.assignedDate {
            return calendar.startOfDay(for: assigned)
        }
        return calendar.startOfDay(for: task.createdAt)
    }

    private func formatMinutes(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return "\(hours)h \(remainder)m"
    }
}
