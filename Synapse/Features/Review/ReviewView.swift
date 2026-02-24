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
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedMonthStart: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
    }()
    @State private var showingDayPicker = false
    @State private var showingMonthPicker = false
    @State private var showingManageHabits = false
    @State private var showingAllTasks = false
    @State private var showingSettings = false
    @State private var showingIdentityDetails = false
    @State private var showingProductivityDetails = false
    @State private var editingTask: TaskItem?
    @State private var habitSort: HabitSort = .completion
    @State private var expandedHabitIDs: Set<UUID> = []

    private enum ReviewMode: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case monthly = "Monthly"

        var id: String { rawValue }
    }

    private enum DayRelation {
        case past
        case today
        case future
    }

    private enum HabitSort: String, CaseIterable {
        case completion = "Completion"
        case name = "Name"
        case longestStreak = "Longest streak"
    }

    private enum TimeBucket: String, CaseIterable, Identifiable {
        case morning
        case afternoon
        case evening

        var id: String { rawValue }

        var label: String {
            switch self {
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            }
        }
    }

    private struct HabitDaySummary {
        let total: Int
        let completed: Int

        var ratio: Double {
            guard total > 0 else { return 0 }
            return Double(completed) / Double(total)
        }

        var isComplete: Bool {
            total > 0 && completed == total
        }

        var isPartial: Bool {
            total > 0 && completed > 0 && completed < total
        }
    }

    private struct DailyInsight: Identifiable {
        let id = UUID()
        let title: String
        let value: String
    }

    private struct MonthMetrics {
        let fullDays: Int
        let partialDays: Int
        let activeDays: Int
        let bestStreak: Int
        let totalFocusMinutes: Int

        var consistencyPercent: Int {
            guard activeDays > 0 else { return 0 }
            return Int((Double(fullDays) / Double(activeDays) * 100).rounded())
        }
    }

    private struct WeekdayPattern {
        let strongestName: String
        let strongestPercent: Int
        let lowestName: String
        let lowestPercent: Int
    }

    private struct HabitTimelineEntry: Identifiable {
        let day: Date
        let completed: Bool

        var id: Date { day }
    }

    private struct HabitMonthStats: Identifiable {
        let habitID: UUID
        let habitTitle: String
        let completionRate: Double?
        let completionRatePercent: Int
        let completionCount: Int
        let activeDays: Int
        let currentStreak: Int
        let longestStreak: Int
        let lastSeven: [HabitTimelineEntry]

        var id: UUID { habitID }
    }

    private struct CorrelationSnapshot {
        let thresholdMinutes: Int
        let highFocusRatePercent: Int?
        let lowFocusRatePercent: Int?
        let highFocusDays: Int
        let lowFocusDays: Int
    }

    private struct MomentumRow: Identifiable {
        let id = UUID()
        let label: String
        let delta: Int
        let unitLabel: String

        var directionSymbol: String {
            if delta > 0 { return "↑" }
            if delta < 0 { return "↓" }
            return "—"
        }

        var valueLabel: String {
            "\(directionSymbol) \(signedValue) (vs last month)"
        }

        var signedValue: String {
            delta > 0 ? "+\(delta)\(unitLabel)" : "\(delta)\(unitLabel)"
        }
    }

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var selectedDayStart: Date { calendar.startOfDay(for: selectedDay) }
    private var previousMonthStart: Date {
        calendar.date(byAdding: .month, value: -1, to: selectedMonthStart) ?? selectedMonthStart
    }

    private let dailyFocusSomeMinutes = 20
    private let dailyFocusHighMinutes = 45
    private let monthlyFocusThresholdMinutes = 30
    private let minimumCorrelationSampleDays = 3

    private var selectedDayRelation: DayRelation {
        if calendar.isDate(selectedDayStart, inSameDayAs: todayStart) {
            return .today
        }
        return selectedDayStart > todayStart ? .future : .past
    }

    private var selectedDayLabel: String {
        selectedDayStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var completionIDsByDay: [Date: Set<UUID>] {
        Dictionary(grouping: habitCompletions) { completion in
            calendar.startOfDay(for: completion.day)
        }
        .mapValues { records in
            Set(records.map(\.habitId))
        }
    }

    private var completionDaysByHabit: [UUID: Set<Date>] {
        Dictionary(grouping: habitCompletions, by: \.habitId).mapValues { records in
            Set(records.map { calendar.startOfDay(for: $0.day) })
        }
    }

    private var dailyActiveHabits: [Habit] {
        habits.filter { isHabit($0, activeOn: selectedDayStart) }
    }

    private var dailyCompletedHabitIDs: Set<UUID> {
        completionIDsByDay[selectedDayStart] ?? []
    }

    private var dailyHabitCompletions: [HabitCompletion] {
        habitCompletions.filter { completion in
            calendar.isDate(completion.day, inSameDayAs: selectedDayStart)
        }
    }

    private var dailyHabitSummary: HabitDaySummary {
        habitSummary(for: selectedDayStart)
    }

    private var dailyCompletedTasks: [TaskItem] {
        tasks
            .filter { task in
                task.state == .completed && calendar.isDate(completionDay(for: task), inSameDayAs: selectedDayStart)
            }
            .sorted { lhs, rhs in
                (lhs.completedAt ?? lhs.createdAt) > (rhs.completedAt ?? rhs.createdAt)
            }
    }

    private var dailyScheduledTasks: [TaskItem] {
        tasks
            .filter { task in
                assignmentDay(for: task) == selectedDayStart && task.state != .inbox
            }
            .sorted { lhs, rhs in
                if lhs.priority.sortRank != rhs.priority.sortRank {
                    return lhs.priority.sortRank < rhs.priority.sortRank
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private var dailySessions: [FocusSession] {
        let end = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) ?? .distantFuture
        return sessions
            .filter { $0.startedAt >= selectedDayStart && $0.startedAt < end }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var dailyFocusSeconds: Int {
        dailySessions.reduce(0) { $0 + $1.durationSeconds }
    }

    private var dailyFocusMinutes: Int {
        max(0, dailyFocusSeconds / 60)
    }

    private var dailyAverageSessionMinutes: Int? {
        guard !dailySessions.isEmpty else { return nil }
        let avg = Double(dailyFocusMinutes) / Double(dailySessions.count)
        return Int(avg.rounded())
    }

    private var dailyFocusMinutesByBucket: [TimeBucket: Int] {
        var output: [TimeBucket: Int] = Dictionary(uniqueKeysWithValues: TimeBucket.allCases.map { ($0, 0) })
        for session in dailySessions {
            let bucket = timeBucket(for: session.startedAt)
            output[bucket, default: 0] += max(0, session.durationSeconds / 60)
        }
        return output
    }

    private var dailyHabitCompletionsByBucket: [TimeBucket: Int] {
        var output: [TimeBucket: Int] = Dictionary(uniqueKeysWithValues: TimeBucket.allCases.map { ($0, 0) })
        for completion in dailyHabitCompletions {
            let bucket = timeBucket(for: completion.completedAt)
            output[bucket, default: 0] += 1
        }
        return output
    }

    private var dailySecondaryInsight: DailyInsight? {
        if let focusBucket = meaningfulLeadingBucket(
            from: dailyFocusMinutesByBucket,
            minimumTotal: dailyFocusSomeMinutes
        ) {
            return DailyInsight(title: "Peak focus window", value: focusBucket.label)
        }
        if let habitBucket = meaningfulLeadingBucket(
            from: dailyHabitCompletionsByBucket,
            minimumTotal: 2
        ) {
            return DailyInsight(title: "Most habits completed", value: habitBucket.label)
        }
        return nil
    }

    private var dailyInsights: [DailyInsight] {
        if selectedDayRelation == .future {
            return [DailyInsight(title: "Insights", value: "Insights will appear once this day begins.")]
        }

        let hasFocusTracking = !dailySessions.isEmpty

        if dailyHabitSummary.total > 0 {
            let alignment = alignmentLabel(
                habitsComplete: dailyHabitSummary.isComplete,
                focusMinutes: dailyFocusMinutes,
                hasFocusTracking: hasFocusTracking
            )
            var items: [DailyInsight] = [
                DailyInsight(title: "Habit-focus alignment", value: alignment)
            ]
            if let secondary = dailySecondaryInsight {
                items.append(secondary)
            }
            return items
        }

        return [DailyInsight(title: "Insights", value: "Log habits, tasks, or focus to reveal patterns.")]
    }

    private var selectedMonthDays: [Date] {
        monthDays(for: selectedMonthStart)
    }

    private var monthGridCells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: selectedMonthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: selectedMonthStart) {
                cells.append(calendar.startOfDay(for: date))
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

    private var selectedMonthDataRange: (start: Date, end: Date, evaluationEndDay: Date?) {
        monthDataRange(for: selectedMonthStart)
    }

    private var selectedMonthSummaries: [Date: HabitDaySummary] {
        Dictionary(uniqueKeysWithValues: selectedMonthDays.map { ($0, habitSummary(for: $0)) })
    }

    private var selectedMonthMetrics: MonthMetrics {
        metrics(for: selectedMonthStart)
    }

    private var previousMonthMetrics: MonthMetrics {
        metrics(for: previousMonthStart)
    }

    private var fullCompleteDayDelta: Int {
        selectedMonthMetrics.fullDays - previousMonthMetrics.fullDays
    }

    private var bestStreakDelta: Int {
        selectedMonthMetrics.bestStreak - previousMonthMetrics.bestStreak
    }

    private var focusMinutesDelta: Int {
        selectedMonthMetrics.totalFocusMinutes - previousMonthMetrics.totalFocusMinutes
    }

    private var momentumRows: [MomentumRow] {
        var rows: [MomentumRow] = []

        if fullCompleteDayDelta != 0 {
            rows.append(
                MomentumRow(
                    label: "Full-complete days",
                    delta: fullCompleteDayDelta,
                    unitLabel: " day\(abs(fullCompleteDayDelta) == 1 ? "" : "s")"
                )
            )
        }
        if bestStreakDelta != 0 {
            rows.append(
                MomentumRow(
                    label: "Best streak",
                    delta: bestStreakDelta,
                    unitLabel: " day\(abs(bestStreakDelta) == 1 ? "" : "s")"
                )
            )
        }
        if focusMinutesDelta != 0 {
            rows.append(
                MomentumRow(
                    label: "Focus time",
                    delta: focusMinutesDelta,
                    unitLabel: "m"
                )
            )
        }

        return rows
    }

    private var strongestTimeOfDayLabel: String {
        guard let strongest = TimeBucket.allCases.max(by: {
            monthlyHabitCompletionsByBucket[$0, default: 0] < monthlyHabitCompletionsByBucket[$1, default: 0]
        }) else {
            return "Balanced"
        }
        if monthlyHabitCompletionsByBucket[strongest, default: 0] == 0 {
            return "Balanced"
        }
        return strongest.label
    }

    private var monthlyStrongestHabitCompletionCount: Int {
        monthlyHabitCompletionsByBucket.values.max() ?? 0
    }

    private var selectedMonthWeekdayPattern: WeekdayPattern? {
        weekdayPattern(for: selectedMonthStart)
    }

    private var selectedMonthCompletions: [HabitCompletion] {
        let range = selectedMonthDataRange
        return habitCompletions.filter { completion in
            let day = calendar.startOfDay(for: completion.day)
            return day >= range.start && day < range.end
        }
    }

    private var selectedMonthSessions: [FocusSession] {
        let range = selectedMonthDataRange
        return sessions.filter { $0.startedAt >= range.start && $0.startedAt < range.end }
    }

    private var monthlyFocusMinutesByBucket: [TimeBucket: Int] {
        var values: [TimeBucket: Int] = Dictionary(uniqueKeysWithValues: TimeBucket.allCases.map { ($0, 0) })
        for session in selectedMonthSessions {
            let bucket = timeBucket(for: session.startedAt)
            values[bucket, default: 0] += max(0, session.durationSeconds / 60)
        }
        return values
    }

    private var monthlyHabitCompletionsByBucket: [TimeBucket: Int] {
        var values: [TimeBucket: Int] = Dictionary(uniqueKeysWithValues: TimeBucket.allCases.map { ($0, 0) })
        for completion in selectedMonthCompletions {
            let bucket = timeBucket(for: completion.completedAt)
            values[bucket, default: 0] += 1
        }
        return values
    }

    private var monthlyCompletedTasks: [TaskItem] {
        let range = selectedMonthDataRange
        return tasks.filter { task in
            guard task.state == .completed else { return false }
            let day = completionDay(for: task)
            return day >= range.start && day < range.end
        }
    }

    private var upcomingScheduledTaskGroups: [(date: Date, tasks: [TaskItem])] {
        let grouped = Dictionary(grouping: tasks.filter { task in
            assignmentDay(for: task) >= todayStart && task.state != .inbox
        }) { task in
            assignmentDay(for: task)
        }

        return grouped
            .keys
            .sorted()
            .map { day in
                let entries = (grouped[day] ?? []).sorted { lhs, rhs in
                    let lhsRank = partOfDaySortRank(lhs.partOfDay)
                    let rhsRank = partOfDaySortRank(rhs.partOfDay)
                    if lhsRank != rhsRank {
                        return lhsRank < rhsRank
                    }
                    return lhs.createdAt < rhs.createdAt
                }
                return (date: day, tasks: entries)
            }
    }

    private var monthlyFocusMinutes: Int {
        selectedMonthSessions.reduce(0) { $0 + max(0, $1.durationSeconds / 60) }
    }

    private var monthlyAverageSessionMinutes: Int? {
        guard !selectedMonthSessions.isEmpty else { return nil }
        let avg = Double(monthlyFocusMinutes) / Double(selectedMonthSessions.count)
        return Int(avg.rounded())
    }

    private var monthlyTasksPerDayAverage: Double? {
        let days = max(1, selectedMonthMetrics.activeDays)
        guard !monthlyCompletedTasks.isEmpty else { return nil }
        return Double(monthlyCompletedTasks.count) / Double(days)
    }

    private var monthlyFocusPerTask: Int? {
        guard monthlyFocusMinutes > 0, !monthlyCompletedTasks.isEmpty else { return nil }
        let perTask = Double(monthlyFocusMinutes) / Double(monthlyCompletedTasks.count)
        return Int(perTask.rounded())
    }

    private var monthlyTasksPerSession: Double? {
        guard !monthlyCompletedTasks.isEmpty, !selectedMonthSessions.isEmpty else { return nil }
        return Double(monthlyCompletedTasks.count) / Double(selectedMonthSessions.count)
    }

    private var habitStats: [HabitMonthStats] {
        habits.map { habit in
            stats(for: habit, monthStart: selectedMonthStart)
        }
    }

    private var sortedHabitStats: [HabitMonthStats] {
        switch habitSort {
        case .completion:
            return habitStats.sorted { lhs, rhs in
                let l = lhs.completionRate ?? 2
                let r = rhs.completionRate ?? 2
                if l != r { return l < r }
                return lhs.habitTitle.localizedCaseInsensitiveCompare(rhs.habitTitle) == .orderedAscending
            }
        case .name:
            return habitStats.sorted {
                $0.habitTitle.localizedCaseInsensitiveCompare($1.habitTitle) == .orderedAscending
            }
        case .longestStreak:
            return habitStats.sorted { lhs, rhs in
                if lhs.longestStreak != rhs.longestStreak {
                    return lhs.longestStreak > rhs.longestStreak
                }
                return lhs.habitTitle.localizedCaseInsensitiveCompare(rhs.habitTitle) == .orderedAscending
            }
        }
    }

    private var monthlyCorrelation: CorrelationSnapshot {
        habitFocusCorrelation(for: selectedMonthStart, thresholdMinutes: monthlyFocusThresholdMinutes)
    }

    private var hasSufficientCorrelationSample: Bool {
        monthlyCorrelation.highFocusDays >= minimumCorrelationSampleDays
            && monthlyCorrelation.lowFocusDays >= minimumCorrelationSampleDays
            && monthlyCorrelation.highFocusRatePercent != nil
            && monthlyCorrelation.lowFocusRatePercent != nil
    }

    private var monthlyNarrativeLine: String {
        guard !habits.isEmpty else {
            return "Add a habit to unlock monthly pattern insights."
        }
        guard selectedMonthDataRange.evaluationEndDay != nil else {
            return "This month is upcoming, and patterns will appear as days unfold."
        }

        if let pattern = selectedMonthWeekdayPattern, hasSufficientCorrelationSample {
            let preferredFocusBucket = (monthlyCorrelation.highFocusRatePercent ?? 0) >= (monthlyCorrelation.lowFocusRatePercent ?? 0)
                ? "\(monthlyCorrelation.thresholdMinutes)m+"
                : "<\(monthlyCorrelation.thresholdMinutes)m"
            return "Strongest weekday: \(pattern.strongestName). Habit completion was higher on \(preferredFocusBucket) focus days."
        }

        if fullCompleteDayDelta != 0 {
            return "Momentum: \(signed(fullCompleteDayDelta)) full-complete days vs last month. Strongest rhythm: \(strongestTimeOfDayLabel)."
        }

        return "This month, \(strongestTimeOfDayLabel) was your strongest rhythm. Best streak: \(selectedMonthMetrics.bestStreak) day\(selectedMonthMetrics.bestStreak == 1 ? "" : "s")."
    }

    private var reviewBottomContentInset: CGFloat {
        mode == .monthly ? 116 : 84
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

                        Color.clear
                            .frame(height: reviewBottomContentInset)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Review")
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAllTasks = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .font(Theme.Typography.iconCompact)
                    }
                    .tint(Theme.text)

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(Theme.Typography.iconCompact)
                    }
                    .tint(Theme.text)
                }
            }
            .sheet(isPresented: $showingDayPicker) {
                ReviewDayPickerSheet(selectedDay: selectedDayStart) { day in
                    selectedDay = calendar.startOfDay(for: day)
                }
            }
            .sheet(isPresented: $showingMonthPicker) {
                MonthYearPickerSheet(
                    selectedMonthStart: selectedMonthStart,
                    minYear: 2000,
                    maxYear: 2100
                ) { month in
                    selectedMonthStart = monthStart(for: month)
                }
            }
            .sheet(isPresented: $showingManageHabits) {
                ManageHabitsView(title: "Identity")
            }
            .sheet(isPresented: $showingAllTasks) {
                AllTasksView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(task: task)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
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
            dailyDateSelector
            dailyIdentityCard
            dailyProductivityCard
            dailyInsightsCard
        }
    }

    private var dailyDateSelector: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button {
                shiftSelectedDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                showingDayPicker = true
            } label: {
                Text(selectedDayLabel)
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(Theme.surface2.opacity(0.92))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .stroke(Theme.textSecondary.opacity(0.12), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)

            Button {
                shiftSelectedDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.sm)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private var dailyIdentityCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("Identity (Habits)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 0)

                if selectedDayRelation == .future {
                    Text("Upcoming")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, Theme.Spacing.xxxs)
                        .background(Capsule(style: .continuous).fill(Theme.surface2))
                }
            }

            if habits.isEmpty {
                Text("No habits yet.")
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)

                Text("Add one habit to begin your identity review.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)

                Button("Add a habit") {
                    showingManageHabits = true
                }
                .font(Theme.Typography.bodySmallStrong)
                .tint(Theme.accent)
            } else {
                metricRow(label: "Habit completion", value: dailyHabitCompletionLabel)

                if selectedDayRelation != .future {
                    habitProgressBar(ratio: dailyHabitSummary.ratio)
                }

                Button(showingIdentityDetails ? "Hide details" : "View details") {
                    withAnimation(.snappy(duration: 0.18)) {
                        showingIdentityDetails.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, Theme.Spacing.xxs)

                if showingIdentityDetails {
                    VStack(spacing: Theme.Spacing.xxs) {
                        ForEach(dailyActiveHabits) { habit in
                            let completed = dailyCompletedHabitIDs.contains(habit.id)
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: completed ? "checkmark.circle.fill" : (selectedDayRelation == .future ? "circle.dashed" : "circle"))
                                    .font(Theme.Typography.iconCompact)
                                    .foregroundStyle(completed ? Theme.accent : Theme.textSecondary.opacity(0.7))

                                Text(habit.title)
                                    .font(Theme.Typography.itemTitle)
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Text(completed ? "Done" : (selectedDayRelation == .future ? "Upcoming" : "Not done"))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.textSecondary.opacity(0.84))
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.surface2.opacity(0.74))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.textSecondary.opacity(0.1), lineWidth: 0.8)
                            }
                        }
                    }
                    .padding(.top, Theme.Spacing.xxs)
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard()
    }

    private var dailyProductivityCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Productivity (Focus + Tasks)")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            if selectedDayRelation == .future {
                metricRow(label: "Tasks scheduled", value: "\(dailyScheduledTasks.count)")
                metricRow(label: "Focus time", value: "—", valueColor: Theme.textSecondary)
                metricRow(label: "Focus sessions", value: "—", valueColor: Theme.textSecondary)
            } else {
                metricRow(label: "Tasks finished", value: "\(dailyCompletedTasks.count)")
                metricRow(label: "Focus time", value: formatMinutesLabel(fromMinutes: dailyFocusMinutes))
                metricRow(label: "Focus sessions", value: "\(dailySessions.count)")

                if let avg = dailyAverageSessionMinutes {
                    metricRow(label: "Avg session length", value: "\(avg)m")
                }
            }

            Button(showingProductivityDetails ? "Hide details" : "View details") {
                withAnimation(.snappy(duration: 0.18)) {
                    showingProductivityDetails.toggle()
                }
            }
            .buttonStyle(.plain)
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.top, Theme.Spacing.xxs)

            if showingProductivityDetails {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if selectedDayRelation == .future {
                        if dailyScheduledTasks.isEmpty {
                            Text("No tasks scheduled yet.")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            detailListTitle("Scheduled tasks")
                            ForEach(dailyScheduledTasks) { task in
                                taskDetailRow(task: task, trailing: task.priority.displayLabel)
                            }
                        }
                    } else {
                        detailListTitle("Tasks finished")
                        if dailyCompletedTasks.isEmpty {
                            Text("No tasks finished yet.")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(dailyCompletedTasks) { task in
                                taskDetailRow(task: task, trailing: task.priority.displayLabel)
                            }
                        }

                        detailListTitle("Focus sessions")
                        if dailySessions.isEmpty {
                            Text("No focus sessions logged.")
                                .font(Theme.Typography.bodySmall)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(dailySessions) { session in
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "timer")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.textSecondary.opacity(0.74))

                                    Text(session.startedAt.formatted(.dateTime.hour().minute()))
                                        .font(Theme.Typography.bodySmall)
                                        .foregroundStyle(Theme.text)

                                    Spacer(minLength: 0)

                                    Text(formatMinutesLabel(fromMinutes: max(0, session.durationSeconds / 60)))
                                        .font(Theme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.vertical, Theme.Spacing.xs)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Theme.surface2.opacity(0.7))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Theme.textSecondary.opacity(0.09), lineWidth: 0.8)
                                }
                            }
                        }
                    }
                }
                .padding(.top, Theme.Spacing.xxs)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private var dailyInsightsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Insights")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            ForEach(dailyInsights) { insight in
                metricRow(label: insight.title, value: insight.value)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .accentTint, cornerRadius: Theme.radiusSmall)
    }

    private var dailyHabitCompletionLabel: String {
        guard selectedDayRelation != .future else { return "—" }
        guard dailyHabitSummary.total > 0 else { return "Not set" }
        return "\(dailyHabitSummary.completed) of \(dailyHabitSummary.total)"
    }

    private var monthlyReview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            monthlyHeader
            monthlyOverviewCard
            monthlyMomentumCard
            monthlyPatternsCard
            monthlyHabitsCard
            monthlyProductivityCard
            monthlyScheduledTasksCard
            monthlyCorrelationsCard
            monthlyNarrativeCard
        }
    }

    private var monthlyHeader: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button {
                selectedMonthStart = monthStart(for: calendar.date(byAdding: .month, value: -1, to: selectedMonthStart) ?? selectedMonthStart)
            } label: {
                Image(systemName: "chevron.left")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                showingMonthPicker = true
            } label: {
                HStack(spacing: Theme.Spacing.xxs) {
                    Text(selectedMonthStart.formatted(.dateTime.month(.wide).year()))
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)

                    Image(systemName: "chevron.down")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        .fill(Theme.surface2.opacity(0.92))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        .stroke(Theme.textSecondary.opacity(0.12), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)

            Button {
                selectedMonthStart = monthStart(for: calendar.date(byAdding: .month, value: 1, to: selectedMonthStart) ?? selectedMonthStart)
            } label: {
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.sm)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private var monthlyOverviewCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Monthly Overview")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            monthHeatmap

            featuredMetricRow(label: "Days fully complete", value: "\(selectedMonthMetrics.fullDays)")
            metricRow(label: "Days partially complete", value: "\(selectedMonthMetrics.partialDays)")
            metricRow(label: "Best streak", value: "\(selectedMonthMetrics.bestStreak) day\(selectedMonthMetrics.bestStreak == 1 ? "" : "s")")
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard()
    }

    private var monthlyMomentumCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Momentum")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            if momentumRows.isEmpty {
                metricRow(label: "Changes", value: "—", valueColor: Theme.textSecondary)
            } else {
                ForEach(momentumRows) { row in
                    metricRow(label: row.label, value: row.valueLabel, valueColor: Theme.text)
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
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

                ForEach(Array(monthGridCells.enumerated()), id: \.offset) { _, cellDay in
                    if let cellDay {
                        monthHeatmapCell(for: cellDay)
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
                            .fill(Theme.accent.opacity(0.10 + (CGFloat(index) * 0.18)))
                            .frame(width: 18, height: 10)
                    }
                }

                Text("More")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func monthHeatmapCell(for day: Date) -> some View {
        let summary = selectedMonthSummaries[day, default: HabitDaySummary(total: 0, completed: 0)]
        let ratio = summary.ratio

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(heatmapFill(for: day, ratio: ratio, hasHabits: summary.total > 0))

            Text(day.formatted(.dateTime.day()))
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.text)
        }
        .frame(height: 32)
    }

    private func heatmapFill(for day: Date, ratio: Double, hasHabits: Bool) -> Color {
        if day > todayStart {
            return Theme.surface2.opacity(0.56)
        }
        guard hasHabits else {
            return Theme.surface2.opacity(0.78)
        }
        if ratio == 0 {
            return Theme.surface2.opacity(0.9)
        }
        return Theme.accent.opacity(0.16 + (0.52 * ratio))
    }

    private var monthlyPatternsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Patterns")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            if let pattern = selectedMonthWeekdayPattern {
                metricRow(
                    label: "Strongest weekday",
                    value: weekdayPatternValue(name: pattern.strongestName, percent: pattern.strongestPercent)
                )
                metricRow(
                    label: "Lowest completion",
                    value: weekdayPatternValue(name: pattern.lowestName, percent: pattern.lowestPercent)
                )
            } else {
                Text("Weekday patterns will appear as habit data accumulates.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
            }

            Rectangle()
                .fill(Theme.textSecondary.opacity(0.12))
                .frame(height: 0.8)
                .padding(.vertical, Theme.Spacing.xxs)

            Text("Time of day")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            ForEach(TimeBucket.allCases) { bucket in
                let habitCompletions = monthlyHabitCompletionsByBucket[bucket, default: 0]
                let focusMinutes = monthlyFocusMinutesByBucket[bucket, default: 0]
                let isStrongest = monthlyStrongestHabitCompletionCount > 0
                    && habitCompletions == monthlyStrongestHabitCompletionCount

                HStack {
                    Text(bucket.label)
                        .font(isStrongest ? Theme.Typography.bodySmallStrong : Theme.Typography.bodySmall)
                        .foregroundStyle(isStrongest ? Theme.text : Theme.textSecondary)

                    Spacer(minLength: 0)

                    Text("Habits \(habitCompletions)")
                        .font(isStrongest ? Theme.Typography.caption.weight(.semibold) : Theme.Typography.caption)
                        .foregroundStyle(isStrongest ? Theme.text : Theme.textSecondary)

                    Text("•")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))

                    Text("Focus \(formatMinutesLabel(fromMinutes: focusMinutes))")
                        .font(Theme.Typography.caption.weight(isStrongest ? .semibold : .medium))
                        .foregroundStyle(isStrongest ? Theme.text : Theme.textSecondary)
                }
                .padding(.vertical, Theme.Spacing.xxxs)
                .padding(.horizontal, Theme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isStrongest ? Theme.accent.opacity(0.09) : Color.clear)
                )
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private var monthlyHabitsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Habits")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 0)

                Menu {
                    ForEach(HabitSort.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            habitSort = option
                        }
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text("Sort: \(habitSort.rawValue)")
                            .font(Theme.Typography.caption.weight(.semibold))
                        Image(systemName: "arrow.up.arrow.down")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxxs)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Theme.accent.opacity(0.1))
                    )
                }
            }

            if habits.isEmpty {
                Text("No habits yet.")
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)

                Button("Add a habit") {
                    showingManageHabits = true
                }
                .font(Theme.Typography.bodySmallStrong)
                .tint(Theme.accent)
            } else {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Habit")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)

                    Spacer(minLength: 0)

                    Text("Rate")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 52, alignment: .trailing)
                    Text("Current")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 58, alignment: .trailing)
                    Text("Longest")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 58, alignment: .trailing)
                }

                VStack(spacing: Theme.Spacing.xxs) {
                    ForEach(sortedHabitStats) { stat in
                        habitStatsRow(stat)
                    }
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .primary, cornerRadius: Theme.radiusSmall)
    }

    private func habitStatsRow(_ stat: HabitMonthStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    if expandedHabitIDs.contains(stat.habitID) {
                        expandedHabitIDs.remove(stat.habitID)
                    } else {
                        expandedHabitIDs.insert(stat.habitID)
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                        Text(stat.habitTitle)
                            .font(Theme.Typography.bodySmallStrong)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)

                        habitRateBar(ratio: stat.completionRate ?? 0)
                            .frame(width: 78)
                    }

                    Spacer(minLength: 0)

                    Text(stat.completionRate == nil ? "—" : "\(stat.completionRatePercent)%")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 52, alignment: .trailing)

                    Text("\(stat.currentStreak)")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 58, alignment: .trailing)

                    Text("\(stat.longestStreak)")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 58, alignment: .trailing)

                    Image(systemName: expandedHabitIDs.contains(stat.habitID) ? "chevron.up" : "chevron.down")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                }
                .padding(.vertical, Theme.Spacing.xs)
                .padding(.horizontal, Theme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.surface2.opacity(0.74))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.textSecondary.opacity(0.1), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)

            if expandedHabitIDs.contains(stat.habitID) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Last 7 active days")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)

                    HStack(spacing: Theme.Spacing.xxs) {
                        ForEach(stat.lastSeven) { entry in
                            VStack(spacing: Theme.Spacing.xxxs) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(entry.completed ? Theme.accent.opacity(0.58) : Theme.surface2)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Theme.textSecondary.opacity(0.12), lineWidth: 0.8)
                                    }
                                    .frame(width: 18, height: 14)

                                Text(entry.day.formatted(.dateTime.day()))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.textSecondary.opacity(0.78))
                            }
                        }
                    }

                    Text("\(stat.completionCount) of \(stat.activeDays) active days complete")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.xxs)
            }
        }
    }

    private var monthlyProductivityCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Productivity")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            Text("Execution")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
            metricRow(label: "Tasks finished", value: "\(monthlyCompletedTasks.count)")
            metricRow(label: "Tasks finished / day", value: monthlyTasksPerDayAverage.map { String(format: "%.1f", $0) } ?? "—")

            Rectangle()
                .fill(Theme.textSecondary.opacity(0.12))
                .frame(height: 0.8)
                .padding(.vertical, Theme.Spacing.xxs)

            Text("Focus")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
            metricRow(label: "Focus time", value: monthlyFocusMinutes > 0 ? formatMinutesLabel(fromMinutes: monthlyFocusMinutes) : "—")
            metricRow(label: "Focus sessions", value: selectedMonthSessions.isEmpty ? "—" : "\(selectedMonthSessions.count)")
            metricRow(label: "Avg session length", value: monthlyAverageSessionMinutes.map { "\($0)m" } ?? "—")
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private var monthlyScheduledTasksCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Scheduled Tasks")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            if upcomingScheduledTaskGroups.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text("No upcoming tasks.")
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                    Text("Use + to schedule something ahead.")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(upcomingScheduledTaskGroups, id: \.date) { group in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(group.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(Theme.Typography.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)

                            VStack(spacing: Theme.Spacing.xxs) {
                                ForEach(group.tasks) { task in
                                    Button {
                                        editingTask = task
                                    } label: {
                                        scheduledTaskRow(task)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private func scheduledTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: task.state == .completed ? "checkmark.circle.fill" : "circle")
                .font(Theme.Typography.caption)
                .foregroundStyle(task.state == .completed ? Theme.accent : Theme.textSecondary.opacity(0.7))

            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text(task.title)
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text(task.partOfDay.displayLabel)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            Text(task.state == .completed ? "Completed" : "Scheduled")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface2.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.textSecondary.opacity(0.1), lineWidth: 0.8)
        }
    }

    private var monthlyCorrelationsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Correlations")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            if hasSufficientCorrelationSample,
               let highRate = monthlyCorrelation.highFocusRatePercent,
               let lowRate = monthlyCorrelation.lowFocusRatePercent {
                metricRow(
                    label: "On \(monthlyCorrelation.thresholdMinutes)m+ focus days",
                    value: "Habits fully complete \(highRate)%"
                )
                metricRow(
                    label: "On <\(monthlyCorrelation.thresholdMinutes)m focus days",
                    value: "Habits fully complete \(lowRate)%"
                )
            } else {
                Text("Not enough data yet.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
            }

            Rectangle()
                .fill(Theme.textSecondary.opacity(0.12))
                .frame(height: 0.8)
                .padding(.vertical, Theme.Spacing.xxs)

            metricRow(label: "Avg focus per task", value: monthlyFocusPerTask.map { "\($0)m" } ?? "—")
            metricRow(label: "Avg tasks per session", value: monthlyTasksPerSession.map { String(format: "%.1f", $0) } ?? "—")
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .primary, cornerRadius: Theme.radiusSmall)
    }

    private var monthlyNarrativeCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Narrative Summary")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            Text(monthlyNarrativeLine)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .accentTint, cornerRadius: Theme.radiusSmall)
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

    private func featuredMetricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            Spacer(minLength: 0)

            Text(value)
                .font(Theme.Typography.itemTitleProminent)
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
        }
    }

    private func habitRateBar(ratio: Double) -> some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Theme.surface.opacity(0.72))

            GeometryReader { proxy in
                Capsule(style: .continuous)
                    .fill(Theme.accent.opacity(0.5))
                    .frame(width: proxy.size.width * max(0, min(1, ratio)))
            }
        }
        .frame(height: 5)
    }

    private func weekdayPatternValue(name: String, percent: Int) -> String {
        if percent == 0 {
            return "\(name) (no completions yet)"
        }
        return "\(name) (\(percent)%)"
    }

    private func alignmentLabel(
        habitsComplete: Bool,
        focusMinutes: Int,
        hasFocusTracking: Bool
    ) -> String {
        guard hasFocusTracking else { return "Habit-focused day" }

        if habitsComplete && focusMinutes >= dailyFocusHighMinutes {
            return "High-alignment day"
        }
        if habitsComplete && focusMinutes < dailyFocusSomeMinutes {
            return "Habit-focused day"
        }
        if !habitsComplete && focusMinutes >= dailyFocusSomeMinutes {
            return "Output-heavy day"
        }
        if !habitsComplete && focusMinutes < dailyFocusSomeMinutes {
            return "Low-activation day"
        }
        return "Habit-focused day"
    }

    private func meaningfulLeadingBucket(from values: [TimeBucket: Int], minimumTotal: Int) -> TimeBucket? {
        let total = values.values.reduce(0, +)
        guard total >= minimumTotal else { return nil }
        guard let strongestValue = values.values.max(), strongestValue > 0 else { return nil }

        let strongestBuckets = values.filter { $0.value == strongestValue }.map(\.key)
        guard strongestBuckets.count == 1 else { return nil }

        return strongestBuckets.first
    }

    private func habitProgressBar(ratio: Double) -> some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Theme.surface2)

            GeometryReader { proxy in
                Capsule(style: .continuous)
                    .fill(Theme.accent.opacity(0.6))
                    .frame(width: proxy.size.width * max(0, min(1, ratio)))
            }
        }
        .frame(height: 7)
    }

    private func detailListTitle(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary.opacity(0.84))
            .padding(.top, Theme.Spacing.xxs)
    }

    private func taskDetailRow(task: TaskItem, trailing: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: task.state == .completed ? "checkmark.circle.fill" : "circle")
                .font(Theme.Typography.caption)
                .foregroundStyle(task.state == .completed ? Theme.accent : Theme.textSecondary.opacity(0.72))

            Text(task.title)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.text)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(trailing)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface2.opacity(0.7))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.textSecondary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func shiftSelectedDay(by value: Int) {
        selectedDay = calendar.date(byAdding: .day, value: value, to: selectedDayStart) ?? selectedDayStart
    }

    private func timeBucket(for date: Date) -> TimeBucket {
        let hour = calendar.component(.hour, from: date)
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }

    private func monthDays(for monthStart: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        return range.compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 1, to: monthStart) else { return nil }
            return calendar.startOfDay(for: date)
        }
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    private func monthDataRange(for monthStartDate: Date) -> (start: Date, end: Date, evaluationEndDay: Date?) {
        let start = monthStart(for: monthStartDate)
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? monthEnd

        if start > todayStart {
            return (start, start, nil)
        }

        let end = min(monthEnd, tomorrowStart)
        guard end > start,
              let evaluationEnd = calendar.date(byAdding: .day, value: -1, to: end) else {
            return (start, start, nil)
        }
        return (start, end, calendar.startOfDay(for: evaluationEnd))
    }

    private func habitSummary(for day: Date) -> HabitDaySummary {
        let target = calendar.startOfDay(for: day)
        let activeForDay = habits.filter { isHabit($0, activeOn: target) }
        guard !activeForDay.isEmpty else { return HabitDaySummary(total: 0, completed: 0) }

        let completedIDs = completionIDsByDay[target] ?? []
        let completedCount = activeForDay.reduce(0) { partial, habit in
            partial + (completedIDs.contains(habit.id) ? 1 : 0)
        }
        return HabitDaySummary(total: activeForDay.count, completed: completedCount)
    }

    private func metrics(for monthStart: Date) -> MonthMetrics {
        let range = monthDataRange(for: monthStart)
        guard let evaluationEnd = range.evaluationEndDay else {
            return MonthMetrics(fullDays: 0, partialDays: 0, activeDays: 0, bestStreak: 0, totalFocusMinutes: 0)
        }

        let days = monthDays(for: monthStart).filter { $0 <= evaluationEnd }
        var fullDays = 0
        var partialDays = 0
        var activeDays = 0
        var bestStreak = 0
        var run = 0

        for day in days {
            let summary = habitSummary(for: day)
            guard summary.total > 0 else { continue }
            activeDays += 1
            if summary.isComplete {
                fullDays += 1
                run += 1
                bestStreak = max(bestStreak, run)
            } else {
                if summary.isPartial {
                    partialDays += 1
                }
                run = 0
            }
        }

        let focusMinutes = sessions
            .filter { $0.startedAt >= range.start && $0.startedAt < range.end }
            .reduce(0) { $0 + max(0, $1.durationSeconds / 60) }

        return MonthMetrics(
            fullDays: fullDays,
            partialDays: partialDays,
            activeDays: activeDays,
            bestStreak: bestStreak,
            totalFocusMinutes: focusMinutes
        )
    }

    private func weekdayPattern(for monthStart: Date) -> WeekdayPattern? {
        let range = monthDataRange(for: monthStart)
        guard let evaluationEnd = range.evaluationEndDay else { return nil }

        let days = monthDays(for: monthStart).filter { $0 <= evaluationEnd }
        let grouped = Dictionary(grouping: days) { day in
            calendar.component(.weekday, from: day)
        }

        let weekdayRates: [(weekday: Int, rate: Double)] = grouped.compactMap { weekday, entries in
            let ratios = entries.compactMap { day -> Double? in
                let summary = habitSummary(for: day)
                guard summary.total > 0 else { return nil }
                return summary.ratio
            }
            guard !ratios.isEmpty else { return nil }
            return (weekday, ratios.reduce(0, +) / Double(ratios.count))
        }

        guard let strongest = weekdayRates.max(by: { $0.rate < $1.rate }),
              let lowest = weekdayRates.min(by: { $0.rate < $1.rate }) else {
            return nil
        }

        let strongestName = calendar.weekdaySymbols[max(0, min(calendar.weekdaySymbols.count - 1, strongest.weekday - 1))]
        let lowestName = calendar.weekdaySymbols[max(0, min(calendar.weekdaySymbols.count - 1, lowest.weekday - 1))]

        return WeekdayPattern(
            strongestName: strongestName,
            strongestPercent: Int((strongest.rate * 100).rounded()),
            lowestName: lowestName,
            lowestPercent: Int((lowest.rate * 100).rounded())
        )
    }

    private func stats(for habit: Habit, monthStart: Date) -> HabitMonthStats {
        let range = monthDataRange(for: monthStart)
        let completionDays = completionDaysByHabit[habit.id] ?? []

        guard let evaluationEnd = range.evaluationEndDay else {
            return HabitMonthStats(
                habitID: habit.id,
                habitTitle: habit.title,
                completionRate: nil,
                completionRatePercent: 0,
                completionCount: 0,
                activeDays: 0,
                currentStreak: 0,
                longestStreak: 0,
                lastSeven: []
            )
        }

        let activeDays = monthDays(for: monthStart)
            .filter { $0 <= evaluationEnd }
            .filter { isHabit(habit, activeOn: $0) }

        let completedDays = activeDays.filter { completionDays.contains($0) }

        let rate: Double?
        if activeDays.isEmpty {
            rate = nil
        } else {
            rate = Double(completedDays.count) / Double(activeDays.count)
        }

        let longest = longestStreak(activeDays: activeDays, completionDays: completionDays)
        let current = currentStreak(activeDays: activeDays, completionDays: completionDays)

        let lastSevenActive = Array(activeDays.suffix(7)).map { day in
            HabitTimelineEntry(day: day, completed: completionDays.contains(day))
        }

        return HabitMonthStats(
            habitID: habit.id,
            habitTitle: habit.title,
            completionRate: rate,
            completionRatePercent: Int(((rate ?? 0) * 100).rounded()),
            completionCount: completedDays.count,
            activeDays: activeDays.count,
            currentStreak: current,
            longestStreak: longest,
            lastSeven: lastSevenActive
        )
    }

    private func currentStreak(activeDays: [Date], completionDays: Set<Date>) -> Int {
        var streak = 0
        for day in activeDays.reversed() {
            if completionDays.contains(day) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func longestStreak(activeDays: [Date], completionDays: Set<Date>) -> Int {
        var best = 0
        var run = 0

        for day in activeDays {
            if completionDays.contains(day) {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }

        return best
    }

    private func habitFocusCorrelation(for monthStart: Date, thresholdMinutes: Int) -> CorrelationSnapshot {
        let range = monthDataRange(for: monthStart)
        guard let evaluationEnd = range.evaluationEndDay else {
            return CorrelationSnapshot(
                thresholdMinutes: thresholdMinutes,
                highFocusRatePercent: nil,
                lowFocusRatePercent: nil,
                highFocusDays: 0,
                lowFocusDays: 0
            )
        }

        let days = monthDays(for: monthStart).filter { $0 <= evaluationEnd }

        var focusMinutesByDay: [Date: Int] = Dictionary(uniqueKeysWithValues: days.map { ($0, 0) })
        for session in sessions where session.startedAt >= range.start && session.startedAt < range.end {
            let day = calendar.startOfDay(for: session.startedAt)
            focusMinutesByDay[day, default: 0] += max(0, session.durationSeconds / 60)
        }

        let evaluableDays = days.filter { habitSummary(for: $0).total > 0 }
        let highDays = evaluableDays.filter { focusMinutesByDay[$0, default: 0] >= thresholdMinutes }
        let lowDays = evaluableDays.filter { focusMinutesByDay[$0, default: 0] < thresholdMinutes }

        func fullRate(for days: [Date]) -> Int? {
            guard !days.isEmpty else { return nil }
            let fullCount = days.filter { habitSummary(for: $0).isComplete }.count
            return Int((Double(fullCount) / Double(days.count) * 100).rounded())
        }

        return CorrelationSnapshot(
            thresholdMinutes: thresholdMinutes,
            highFocusRatePercent: fullRate(for: highDays),
            lowFocusRatePercent: fullRate(for: lowDays),
            highFocusDays: highDays.count,
            lowFocusDays: lowDays.count
        )
    }

    private func isHabit(_ habit: Habit, activeOn day: Date) -> Bool {
        HabitAnalytics.isHabit(
            habit,
            activeOn: day,
            today: todayStart,
            pausePeriods: habitPausePeriods,
            calendar: calendar
        )
    }

    private func assignmentDay(for task: TaskItem) -> Date {
        if let assigned = task.assignedDate {
            return calendar.startOfDay(for: assigned)
        }
        return calendar.startOfDay(for: task.createdAt)
    }

    private func completionDay(for task: TaskItem) -> Date {
        if let completedAt = task.completedAt {
            return calendar.startOfDay(for: completedAt)
        }
        return assignmentDay(for: task)
    }

    private func partOfDaySortRank(_ partOfDay: TaskPartOfDay) -> Int {
        switch partOfDay {
        case .morning: return 0
        case .afternoon: return 1
        case .evening: return 2
        case .anytime: return 3
        }
    }

    private func formatMinutesLabel(fromMinutes minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        if safeMinutes < 60 { return "\(safeMinutes)m" }
        let hours = safeMinutes / 60
        let remainder = safeMinutes % 60
        return "\(hours)h \(remainder)m"
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

private struct ReviewDayPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedDay: Date
    let onSelect: (Date) -> Void

    @State private var pickerDate: Date

    private var calendar: Calendar { .current }

    init(selectedDay: Date, onSelect: @escaping (Date) -> Void) {
        self.selectedDay = selectedDay
        self.onSelect = onSelect
        _pickerDate = State(initialValue: selectedDay)
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas(daySeed: pickerDate) {
                VStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Select a day")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)

                        DatePicker(
                            "Day",
                            selection: $pickerDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(Theme.accent)
                    }
                    .padding(Theme.Spacing.cardInset)
                    .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Choose Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(Theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSelect(calendar.startOfDay(for: pickerDate))
                        dismiss()
                    }
                    .tint(Theme.accent)
                }
            }
        }
    }
}
