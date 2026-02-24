import SwiftUI
import SwiftData

struct ManageHabitsView: View {
    var title: String = "Rituals"
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

    @State private var showingAddRitual = false
    @State private var editingHabit: Habit?
    @State private var showPausedSection = false
    @State private var reorderMode: EditMode = .inactive

    private struct RitualRowMetrics {
        let monthlyPercent: Int
        let completedDays: Int
        let eligibleDays: Int
        let currentStreak: Int
    }

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var currentMonthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
    }

    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    private var pausedHabits: [Habit] {
        habits.filter { !$0.isActive }
    }

    private var bestMonthlyStreak: Int {
        activeHabits
            .map {
                RitualAnalytics.bestStreakInMonth(
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
            let monthly = RitualAnalytics.monthlyCompletion(
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

    private var nextSortOrder: Int {
        (habits.map(\.sortOrder).max() ?? -1) + 1
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        identitySummaryCard
                        activeRitualsZone
                        pausedRitualsZone
                        Spacer(minLength: 0)
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle(title)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddRitual = true
                    } label: {
                        Image(systemName: "plus")
                            .font(Theme.Typography.iconCompact)
                    }
                    .tint(Theme.accent)
                }

                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .tint(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAddRitual) {
                RitualEditorSheet(defaultSortOrder: nextSortOrder)
            }
            .sheet(item: $editingHabit) { habit in
                RitualEditorSheet(habit: habit, defaultSortOrder: habit.sortOrder)
            }
            .onAppear {
                normalizeSortOrderIfNeeded()
            }
        }
    }

    private var identitySummaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Identity Summary")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            metricRow(label: "Best streak (month)", value: "\(bestMonthlyStreak) day\(bestMonthlyStreak == 1 ? "" : "s")")
            metricRow(label: "Monthly completion", value: "\(monthlyCompletionPercent)%")
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private var activeRitualsZone: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                SectionLabel(icon: "leaf", title: "Active Rituals")

                Spacer(minLength: 0)

                if !activeHabits.isEmpty {
                    Button(reorderMode == .active ? "Done" : "Reorder") {
                        withAnimation(.snappy(duration: 0.18)) {
                            reorderMode = (reorderMode == .active) ? .inactive : .active
                        }
                    }
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.plain)
                }
            }

            if activeHabits.isEmpty {
                EmptyStatePanel(
                    symbol: "leaf",
                    title: "No rituals yet.",
                    subtitle: "Use + to configure your first ritual."
                )
            } else {
                List {
                    ForEach(activeHabits) { habit in
                        activeRitualRow(for: habit)
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
            }
        }
    }

    private func activeRitualRow(for habit: Habit) -> some View {
        let metrics = metrics(for: habit)

        return VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text(habit.title)
                        .font(Theme.Typography.itemTitle)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)

                    Text("\(habit.frequencySummary) • \(habit.timeOfDay.displayLabel)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: Theme.Spacing.xxxs) {
                    Text("\(metrics.currentStreak)d")
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                    Text("\(metrics.monthlyPercent)%")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                actionPill(title: "Edit") {
                    editingHabit = habit
                }

                actionPill(title: "Pause") {
                    pause(habit)
                }

                actionPill(title: "Delete", role: .destructive) {
                    delete(habit)
                }
            }

            Text("\(metrics.completedDays) / \(metrics.eligibleDays) eligible days this month")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary.opacity(0.78))
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var pausedRitualsZone: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            DisclosureGroup(isExpanded: $showPausedSection) {
                VStack(spacing: Theme.Spacing.xxs) {
                    if pausedHabits.isEmpty {
                        Text("No paused rituals.")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(pausedHabits) { habit in
                            pausedRitualRow(for: habit)
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

    private func pausedRitualRow(for habit: Habit) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text(habit.title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text("\(habit.frequencySummary) • \(habit.timeOfDay.displayLabel)")
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
        let rowHeight: CGFloat = 134
        return max(120, min(CGFloat(activeHabits.count) * rowHeight, 520))
    }

    private func metrics(for habit: Habit) -> RitualRowMetrics {
        let monthly = RitualAnalytics.monthlyCompletion(
            for: habit,
            monthStart: currentMonthStart,
            completions: completions,
            pausePeriods: pausePeriods,
            today: todayStart,
            calendar: calendar
        )

        return RitualRowMetrics(
            monthlyPercent: monthly.percent,
            completedDays: monthly.completedDays,
            eligibleDays: monthly.eligibleDays,
            currentStreak: RitualAnalytics.currentStreak(
                for: habit,
                completions: completions,
                pausePeriods: pausePeriods,
                today: todayStart,
                calendar: calendar
            )
        )
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

    private func actionPill(title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(Theme.Typography.caption.weight(.semibold))
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, Theme.Spacing.xxxs)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.surface2)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Theme.textSecondary : Theme.accent)
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
            print("Ritual reorder error: \(error)")
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
            print("Ritual delete error: \(error)")
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
            print("Ritual pause error: \(error)")
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
            print("Ritual resume error: \(error)")
        }
    }
}
