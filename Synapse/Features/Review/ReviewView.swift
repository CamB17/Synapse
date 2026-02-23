import SwiftUI
import SwiftData

struct ReviewView: View {
    @Query(sort: [SortDescriptor(\TaskItem.createdAt, order: .forward)])
    private var tasks: [TaskItem]

    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .forward)])
    private var sessions: [FocusSession]

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @State private var mode: ReviewMode = .daily

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
    }

    private enum ReviewMode: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case monthly = "Monthly"

        var id: String { rawValue }
    }

    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    private var completedHabitsToday: Int {
        activeHabits.filter(\.completedToday).count
    }

    private var dailyAssignedTasks: [TaskItem] {
        tasks.filter { task in
            task.state == .today || task.state == .completed
        }
        .filter { task in
            calendar.isDate(assignmentDay(for: task), inSameDayAs: todayStart)
        }
    }

    private var dailyCompletedTasks: [TaskItem] {
        tasks.filter { task in
            task.state == .completed && calendar.isDate(assignmentDay(for: task), inSameDayAs: todayStart)
        }
    }

    private var dailyCompletionPercent: Int {
        guard !dailyAssignedTasks.isEmpty else { return 0 }
        let raw = (Double(dailyCompletedTasks.count) / Double(dailyAssignedTasks.count)) * 100
        return Int(raw.rounded())
    }

    private var dailyRitualConsistency: Int {
        guard !activeHabits.isEmpty else { return 0 }
        let raw = (Double(completedHabitsToday) / Double(activeHabits.count)) * 100
        return Int(raw.rounded())
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

    private var maxDailyTrendCompletions: Int {
        max(1, dailyTrendDays.map { dailyTaskSummary(for: $0).completed }.max() ?? 0)
    }

    private var dailyInsightLine: String {
        if dailyCompletionPercent >= 80 && dailyRitualConsistency >= 80 {
            return "Strong execution day. Keep tomorrow equally simple."
        }
        if dailyCompletedTasks.isEmpty {
            return "One completed task creates momentum faster than planning more."
        }
        if dailyRitualConsistency < 50 {
            return "Ritual consistency is the easiest lever to stabilize execution."
        }
        return "Progress is steady. Protect focus blocks and keep priorities tight."
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

    private var monthTaskSummaries: [Date: (assigned: Int, completed: Int)] {
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? .distantFuture
        let monthTasks = tasks.filter { task in
            let day = assignmentDay(for: task)
            return day >= monthStart && day < monthEnd && (task.state == .today || task.state == .completed)
        }

        return Dictionary(grouping: monthTasks) { task in
            assignmentDay(for: task)
        }
        .mapValues { items in
            let assigned = items.count
            let completed = items.filter { $0.state == .completed }.count
            return (assigned, completed)
        }
    }

    private var monthlyBestStreak: Int {
        let completionDays = monthTaskSummaries
            .filter { _, summary in summary.completed > 0 }
            .keys
            .sorted()

        guard !completionDays.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for index in 1..<completionDays.count {
            let previous = completionDays[index - 1]
            let expected = calendar.date(byAdding: .day, value: 1, to: previous) ?? previous
            if calendar.isDate(completionDays[index], inSameDayAs: expected) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    private var monthlyAverageExecutionPercent: Int {
        let values = monthTaskSummaries.values.compactMap { summary -> Double? in
            guard summary.assigned > 0 else { return nil }
            return Double(summary.completed) / Double(summary.assigned)
        }

        guard !values.isEmpty else { return 0 }
        let avg = values.reduce(0, +) / Double(values.count)
        return Int((avg * 100).rounded())
    }

    private var monthlyWeekdayStrength: (strongest: String, weakest: String)? {
        let groupedByWeekday = Dictionary(grouping: monthTaskSummaries) { entry in
            calendar.component(.weekday, from: entry.key)
        }

        let averages: [(weekday: Int, score: Double)] = groupedByWeekday.map { weekday, entries in
            let values = entries.compactMap { _, summary -> Double? in
                guard summary.assigned > 0 else { return nil }
                return Double(summary.completed) / Double(summary.assigned)
            }
            let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
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
            Text("Daily graph")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            dailyTrendStrip

            metricRow(label: "Completion %", value: "\(dailyCompletionPercent)%")
            metricRow(label: "Ritual consistency", value: "\(dailyRitualConsistency)%")
            metricRow(label: "Task throughput", value: "\(dailyCompletedTasks.count)")
            metricRow(label: "Focus time", value: formatMinutes(dailyFocusSeconds))

            Text(dailyInsightLine)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard()
    }

    private var dailyTrendStrip: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xxs) {
            ForEach(dailyTrendDays, id: \.self) { day in
                let summary = dailyTaskSummary(for: day)
                let normalized = CGFloat(summary.completed) / CGFloat(maxDailyTrendCompletions)

                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(Theme.accent.opacity(summary.completed == 0 ? 0.12 : 0.24 + (0.32 * normalized)))
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
            metricRow(label: "Avg execution %", value: "\(monthlyAverageExecutionPercent)%")

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
        let summary = monthTaskSummaries[calendar.startOfDay(for: day), default: (assigned: 0, completed: 0)]
        let ratio: CGFloat
        if summary.assigned == 0 {
            ratio = 0
        } else {
            ratio = CGFloat(summary.completed) / CGFloat(summary.assigned)
        }

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(summary.assigned == 0 ? Theme.surface2 : Theme.accent.opacity(0.12 + (0.58 * ratio)))

            Text(day.formatted(.dateTime.day()))
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.text)
        }
        .frame(height: 32)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Spacer(minLength: 0)

            Text(value)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
        }
    }

    private func dailyTaskSummary(for day: Date) -> (assigned: Int, completed: Int) {
        let target = calendar.startOfDay(for: day)
        let assigned = tasks.filter { task in
            (task.state == .today || task.state == .completed)
                && calendar.isDate(assignmentDay(for: task), inSameDayAs: target)
        }.count
        let completed = tasks.filter { task in
            task.state == .completed && calendar.isDate(assignmentDay(for: task), inSameDayAs: target)
        }.count
        return (assigned, completed)
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
