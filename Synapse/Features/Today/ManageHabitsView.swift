import SwiftUI
import SwiftData
import UIKit

struct ManageHabitsView: View {
    var title: String = "Habits"
    var showsDoneButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .forward)
    ])
    private var habits: [Habit]

    @Query(sort: [SortDescriptor(\HabitCompletion.day, order: .reverse)])
    private var completions: [HabitCompletion]

    @Query(sort: [SortDescriptor(\HabitPausePeriod.startDay, order: .reverse)])
    private var pausePeriods: [HabitPausePeriod]

    @State private var showingAddHabit = false
    @State private var selectedHabitForDetail: Habit?
    @State private var showPausedSection = false
    @State private var reorderMode: EditMode = .inactive
    @State private var showingHabitSettingsHint = false

    private struct HabitRowMetrics {
        let completionRatePercent: Int
        let completedDays: Int
        let eligibleDays: Int
        let currentStreak: Int
        let longestStreak: Int
    }

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var currentMonthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
    }
    private var thirtyDayWindowStart: Date {
        calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
    }

    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    private var pausedHabits: [Habit] {
        habits.filter { !$0.isActive }
    }

    private var nextSortOrder: Int {
        (habits.map(\.sortOrder).max() ?? -1) + 1
    }

    private var bestMonthlyStreak: Int {
        activeHabits
            .map {
                HabitAnalytics.bestStreakInMonth(
                    for: $0,
                    monthStart: currentMonthStart,
                    completions: completions,
                    pausePeriods: pausePeriods,
                    today: todayStart,
                    calendar: calendar
                )
            }
            .max() ?? 0
    }

    private var monthlyCompletionPercent: Int {
        let totals = activeHabits.reduce(into: (completed: 0, eligible: 0)) { partial, habit in
            let monthly = HabitAnalytics.monthlyCompletion(
                for: habit,
                monthStart: currentMonthStart,
                completions: completions,
                pausePeriods: pausePeriods,
                today: todayStart,
                calendar: calendar
            )
            partial.completed += monthly.completedDays
            partial.eligible += monthly.eligibleDays
        }

        guard totals.eligible > 0 else { return 0 }
        return Int((Double(totals.completed) / Double(totals.eligible) * 100).rounded())
    }

    private var mostConsistentHabitName: String? {
        let scored = activeHabits
            .map { ($0, metrics(for: $0).completionRatePercent) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }

        guard let top = scored.first, top.1 > 0 else { return nil }
        return top.0.title
    }

    private var monthlyInsightLine: String? {
        let habitsByPart = Dictionary(grouping: activeHabits, by: \.timeOfDay)
        let scored = habitsByPart.map { part, habits in
            let average = habits.map { Double(metrics(for: $0).completionRatePercent) }.reduce(0, +) / Double(max(1, habits.count))
            return (part: part, average: average)
        }
        .sorted { $0.average > $1.average }

        guard let top = scored.first else { return nil }
        guard top.part == .morning else { return nil }
        let second = scored.dropFirst().first?.average ?? 0
        guard top.average >= 55, top.average - second >= 5 else { return nil }
        return "Mornings are your strongest rhythm."
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        topIntro
                        monthSummaryCard
                        activeHabitsZone
                        pausedHabitsZone
                        Spacer(minLength: 0)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                            .font(Theme.Typography.iconCompact)
                    }
                    .tint(Theme.accent)
                    .help("Add habit")
                    .accessibilityLabel("Add habit")

                    overflowMenu
                }

                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .tint(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                HabitEditorSheet(defaultSortOrder: nextSortOrder)
            }
            .sheet(item: $selectedHabitForDetail) { habit in
                HabitDetailSheet(
                    habit: habit,
                    completions: completions,
                    pausePeriods: pausePeriods,
                    onPause: {
                        if habit.isActive {
                            pause(habit)
                        } else {
                            resume(habit)
                        }
                    },
                    onDelete: {
                        delete(habit)
                    }
                )
            }
            .alert("Habit settings live in Settings.", isPresented: $showingHabitSettingsHint) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                normalizeSortOrderIfNeeded()
            }
        }
    }

    private var topIntro: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
            Text("Habits")
                .font(Theme.Typography.titleLarge)
                .foregroundStyle(Theme.text)

            Text("Your routines, made effortless.")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var overflowMenu: some View {
        Menu {
            if activeHabits.count > 1 {
                Button(reorderMode == .active ? "Done reordering" : "Reorder habits") {
                    withAnimation(Motion.easing) {
                        reorderMode = (reorderMode == .active) ? .inactive : .active
                    }
                }
            }

            Button("View paused habits") {
                withAnimation(Motion.easing) {
                    showPausedSection = true
                }
            }

            Button("Habit settings") {
                showingHabitSettingsHint = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(Theme.Typography.iconCompact)
        }
        .tint(Theme.textSecondary)
        .accessibilityLabel("Habit actions")
    }

    private var monthSummaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("This month")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                summaryMetric("Best streak: \(bestMonthlyStreak) day\(bestMonthlyStreak == 1 ? "" : "s")")
                summaryMetric("Completion: \(monthlyCompletionPercent)%")
                if let mostConsistentHabitName {
                    summaryMetric("Most consistent: \(mostConsistentHabitName)")
                }
            }

            if let monthlyInsightLine {
                Text(monthlyInsightLine)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    .padding(.top, Theme.Spacing.xxs)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private func summaryMetric(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.bodySmall)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeHabitsZone: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("Active")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 0)

                if reorderMode == .active {
                    Text("Drag to reorder")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.76))
                }
            }

            if activeHabits.isEmpty {
                EmptyStatePanel(
                    symbol: "leaf",
                    title: "No habits yet.",
                    subtitle: "Use + to add your first habit."
                )
            } else if reorderMode == .active {
                List {
                    ForEach(activeHabits) { habit in
                        reorderHabitRow(for: habit)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove(perform: moveActiveHabits)
                }
                .environment(\.editMode, $reorderMode)
                .scrollDisabled(true)
                .frame(height: activeListHeight)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(activeHabits) { habit in
                        activeHabitRow(for: habit)
                    }
                }
            }
        }
    }

    private func activeHabitRow(for habit: Habit) -> some View {
        let metrics = metrics(for: habit)

        return Button {
            let feedback = UIImpactFeedbackGenerator(style: .soft)
            feedback.impactOccurred()
            withAnimation(Motion.easing) {
                selectedHabitForDetail = habit
            }
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text(habit.title)
                        .font(Theme.Typography.itemTitle)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)

                    Text("\(frequencyLine(for: habit)) • \(habit.timeOfDay.displayLabel)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: Theme.Spacing.xxxs) {
                    Text("\(metrics.currentStreak)d")
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                    Text("\(metrics.completionRatePercent)%")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                }
            }
            .padding(Theme.Spacing.cardInset)
            .surfaceCard(cornerRadius: Theme.radiusSmall)
        }
        .buttonStyle(.plain)
    }

    private func reorderHabitRow(for habit: Habit) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text(habit.title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text("\(frequencyLine(for: habit)) • \(habit.timeOfDay.displayLabel)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var pausedHabitsZone: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            DisclosureGroup(isExpanded: $showPausedSection) {
                VStack(spacing: Theme.Spacing.xxs) {
                    if pausedHabits.isEmpty {
                        Text("No paused habits.")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(pausedHabits) { habit in
                            pausedHabitRow(for: habit)
                        }
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            } label: {
                HStack {
                    Text("Paused (\(pausedHabits.count))")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                }
            }
            .tint(Theme.textSecondary)
            .padding(Theme.Spacing.cardInset)
            .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
        }
    }

    private func pausedHabitRow(for habit: Habit) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text(habit.title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text("\(frequencyLine(for: habit)) • \(habit.timeOfDay.displayLabel)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            Button("Resume") {
                resume(habit)
            }
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var activeListHeight: CGFloat {
        let rowHeight: CGFloat = 92
        return max(120, min(CGFloat(activeHabits.count) * rowHeight, 560))
    }

    private func frequencyLine(for habit: Habit) -> String {
        switch habit.frequency {
        case .daily:
            return "Daily"
        case .weekly, .custom:
            let count = max(1, habit.scheduledWeekdays.count)
            return "\(count)x per week"
        }
    }

    private func metrics(for habit: Habit) -> HabitRowMetrics {
        let rolling = thirtyDayCompletion(for: habit)

        return HabitRowMetrics(
            completionRatePercent: rolling.percent,
            completedDays: rolling.completedDays,
            eligibleDays: rolling.eligibleDays,
            currentStreak: HabitAnalytics.currentStreak(
                for: habit,
                completions: completions,
                pausePeriods: pausePeriods,
                today: todayStart,
                calendar: calendar
            ),
            longestStreak: longestStreak(for: habit)
        )
    }

    private func thirtyDayCompletion(for habit: Habit) -> (completedDays: Int, eligibleDays: Int, percent: Int) {
        let completedDays = HabitAnalytics.completionDays(for: habit.id, completions: completions, calendar: calendar)

        var eligible = 0
        var completed = 0
        var cursor = thirtyDayWindowStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        while cursor < end {
            if HabitAnalytics.isHabit(
                habit,
                activeOn: cursor,
                today: todayStart,
                pausePeriods: pausePeriods,
                calendar: calendar
            ) {
                eligible += 1
                if completedDays.contains(cursor) {
                    completed += 1
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let percent = eligible == 0 ? 0 : Int((Double(completed) / Double(eligible) * 100).rounded())
        return (completed, eligible, percent)
    }

    private func longestStreak(for habit: Habit) -> Int {
        let completedDays = HabitAnalytics.completionDays(for: habit.id, completions: completions, calendar: calendar)
        let createdStart = calendar.startOfDay(for: habit.createdAt)

        var cursor = createdStart
        var run = 0
        var best = 0
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        while cursor < end {
            if HabitAnalytics.isHabit(
                habit,
                activeOn: cursor,
                today: todayStart,
                pausePeriods: pausePeriods,
                calendar: calendar
            ) {
                if completedDays.contains(cursor) {
                    run += 1
                    best = max(best, run)
                } else {
                    run = 0
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return best
    }

    private func normalizeSortOrderIfNeeded() {
        guard habits.count > 1 else { return }

        let expected = habits.indices
        let current = habits.map(\.sortOrder)
        let alreadyOrdered = zip(expected, current).allSatisfy { $0 == $1 }
        guard !alreadyOrdered else { return }

        for (index, habit) in habits.enumerated() {
            habit.sortOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            print("Sort order normalize error: \(error)")
        }
    }

    private func moveActiveHabits(from source: IndexSet, to destination: Int) {
        var reordered = activeHabits
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, habit) in reordered.enumerated() {
            habit.sortOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            print("Habit reorder error: \(error)")
        }
    }

    private func delete(_ habit: Habit) {
        modelContext.delete(habit)
        for period in pausePeriods where period.habitId == habit.id {
            modelContext.delete(period)
        }
        for completion in completions where completion.habitId == habit.id {
            modelContext.delete(completion)
        }

        do {
            try modelContext.save()
        } catch {
            print("Habit delete error: \(error)")
        }
    }

    private func pause(_ habit: Habit) {
        guard habit.isActive else { return }

        habit.isActive = false
        if !pausePeriods.contains(where: { $0.habitId == habit.id && $0.endDay == nil }) {
            modelContext.insert(HabitPausePeriod(habitId: habit.id, startDay: .now))
        }

        do {
            try modelContext.save()
        } catch {
            print("Habit pause error: \(error)")
        }
    }

    private func resume(_ habit: Habit) {
        guard !habit.isActive else { return }

        habit.isActive = true
        habit.sortOrder = nextSortOrder

        if let period = pausePeriods.first(where: { $0.habitId == habit.id && $0.endDay == nil }) {
            period.endDay = todayStart
        }

        do {
            try modelContext.save()
        } catch {
            print("Habit resume error: \(error)")
        }
    }
}

private struct HabitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let habit: Habit
    let completions: [HabitCompletion]
    let pausePeriods: [HabitPausePeriod]
    let onPause: () -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var frequency: HabitFrequency
    @State private var timeOfDay: TaskPartOfDay
    @State private var selectedWeekdays: Set<Int>
    @State private var showDeleteConfirmation = false

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }

    init(
        habit: Habit,
        completions: [HabitCompletion],
        pausePeriods: [HabitPausePeriod],
        onPause: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.habit = habit
        self.completions = completions
        self.pausePeriods = pausePeriods
        self.onPause = onPause
        self.onDelete = onDelete

        _title = State(initialValue: habit.title)
        _frequency = State(initialValue: habit.frequency)
        _timeOfDay = State(initialValue: habit.timeOfDay)
        _selectedWeekdays = State(initialValue: habit.scheduledWeekdays)
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        nameCard
                        frequencyCard
                        timeCard
                        streakCard
                        miniGraphCard
                        actionsCard
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .tint(Theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .tint(Theme.accent)
                    .disabled(saveDisabled)
                }
            }
            .alert("Delete habit?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the habit and its completion history.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Habit name")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            TextField("Habit name", text: $title)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var frequencyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Frequency")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Picker("Frequency", selection: $frequency) {
                Text("Daily").tag(HabitFrequency.daily)
                Text("Weekly").tag(HabitFrequency.weekly)
                Text("Custom").tag(HabitFrequency.custom)
            }
            .pickerStyle(.segmented)

            if frequency == .weekly || frequency == .custom {
                weekdayPicker
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Time of day")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Picker("Time of day", selection: $timeOfDay) {
                Text(TaskPartOfDay.anytime.displayLabel).tag(TaskPartOfDay.anytime)
                Text(TaskPartOfDay.morning.displayLabel).tag(TaskPartOfDay.morning)
                Text(TaskPartOfDay.afternoon.displayLabel).tag(TaskPartOfDay.afternoon)
                Text(TaskPartOfDay.evening.displayLabel).tag(TaskPartOfDay.evening)
            }
            .pickerStyle(.segmented)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Progress")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            metricRow(label: "Current streak", value: "\(currentStreak) day\(currentStreak == 1 ? "" : "s")")
            metricRow(label: "Longest streak", value: "\(longestStreak) day\(longestStreak == 1 ? "" : "s")")
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var miniGraphCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("30-day completion")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(lastThirtyDayBars, id: \.day) { bar in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(bar.color)
                        .frame(width: 6, height: bar.height)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(completionPercent)% complete")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var actionsCard: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button {
                let feedback = UIImpactFeedbackGenerator(style: .soft)
                feedback.impactOccurred()
                onPause()
                dismiss()
            } label: {
                Text(habit.isActive ? "Pause Habit" : "Resume Habit")
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(Theme.surface2)
                    )
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("Delete Habit")
                    .font(Theme.Typography.bodySmallStrong)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private struct DayBar {
        let day: Date
        let color: Color
        let height: CGFloat
    }

    private var lastThirtyDayBars: [DayBar] {
        let completedDays = HabitAnalytics.completionDays(for: habit.id, completions: completions, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        var bars: [DayBar] = []
        var cursor = start

        while cursor < end {
            let eligible = HabitAnalytics.isHabit(
                habit,
                activeOn: cursor,
                today: todayStart,
                pausePeriods: pausePeriods,
                calendar: calendar
            )
            let completed = completedDays.contains(cursor)

            let bar = DayBar(
                day: cursor,
                color: completed ? Theme.accent : (eligible ? Theme.surface2.opacity(0.9) : Theme.surface2.opacity(0.45)),
                height: completed ? 18 : (eligible ? 11 : 6)
            )
            bars.append(bar)

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return bars
    }

    private var completionPercent: Int {
        let completedDays = HabitAnalytics.completionDays(for: habit.id, completions: completions, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        var eligible = 0
        var completed = 0
        var cursor = start

        while cursor < end {
            if HabitAnalytics.isHabit(
                habit,
                activeOn: cursor,
                today: todayStart,
                pausePeriods: pausePeriods,
                calendar: calendar
            ) {
                eligible += 1
                if completedDays.contains(cursor) {
                    completed += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        guard eligible > 0 else { return 0 }
        return Int((Double(completed) / Double(eligible) * 100).rounded())
    }

    private var currentStreak: Int {
        HabitAnalytics.currentStreak(
            for: habit,
            completions: completions,
            pausePeriods: pausePeriods,
            today: todayStart,
            calendar: calendar
        )
    }

    private var longestStreak: Int {
        let completedDays = HabitAnalytics.completionDays(for: habit.id, completions: completions, calendar: calendar)
        let createdStart = calendar.startOfDay(for: habit.createdAt)

        var cursor = createdStart
        var run = 0
        var best = 0
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        while cursor < end {
            if HabitAnalytics.isHabit(
                habit,
                activeOn: cursor,
                today: todayStart,
                pausePeriods: pausePeriods,
                calendar: calendar
            ) {
                if completedDays.contains(cursor) {
                    run += 1
                    best = max(best, run)
                } else {
                    run = 0
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return best
    }

    private var saveDisabled: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if (frequency == .weekly || frequency == .custom) && selectedWeekdays.isEmpty { return true }
        return false
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(frequency == .weekly ? "Day" : "Days")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: Theme.Spacing.xxs)], spacing: Theme.Spacing.xxs) {
                ForEach(orderedWeekdayValues, id: \.self) { day in
                    weekdayChip(day)
                }
            }
        }
        .padding(.top, Theme.Spacing.xxxs)
    }

    private func weekdayChip(_ day: Int) -> some View {
        let isSelected = selectedWeekdays.contains(day)

        return Button {
            withAnimation(Motion.easing) {
                toggleWeekday(day)
            }
        } label: {
            Text(weekdayLabel(for: day))
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Theme.accent.opacity(0.14) : Theme.surface2)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Theme.accent.opacity(0.46) : Theme.textSecondary.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var orderedWeekdayValues: [Int] {
        let base = Array(1...7)
        let start = calendar.firstWeekday
        return base.sorted { lhs, rhs in
            let left = (lhs - start + 7) % 7
            let right = (rhs - start + 7) % 7
            return left < right
        }
    }

    private func toggleWeekday(_ day: Int) {
        if frequency == .weekly {
            selectedWeekdays = [day]
            return
        }

        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
            if selectedWeekdays.isEmpty {
                selectedWeekdays.insert(day)
            }
        } else {
            selectedWeekdays.insert(day)
        }
    }

    private func weekdayLabel(for day: Int) -> String {
        let safe = max(1, min(7, day)) - 1
        return calendar.shortWeekdaySymbols[safe]
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
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalizedWeekdays: Set<Int>
        switch frequency {
        case .daily:
            normalizedWeekdays = []
        case .weekly:
            normalizedWeekdays = [selectedWeekdays.sorted().first ?? calendar.component(.weekday, from: .now)]
        case .custom:
            normalizedWeekdays = selectedWeekdays.isEmpty ? [calendar.component(.weekday, from: .now)] : selectedWeekdays
        }

        habit.title = trimmed
        habit.frequency = frequency
        habit.timeOfDay = timeOfDay
        habit.scheduledWeekdays = normalizedWeekdays

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Habit detail save error: \(error)")
        }
    }
}
