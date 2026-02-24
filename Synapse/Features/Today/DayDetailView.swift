import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @Query(sort: [SortDescriptor(\HabitCompletion.day, order: .reverse)])
    private var completions: [HabitCompletion]

    @Query(sort: [SortDescriptor(\HabitPausePeriod.startDay, order: .reverse)])
    private var pausePeriods: [HabitPausePeriod]

    @Query(sort: [SortDescriptor(\TaskItem.createdAt, order: .forward)])
    private var tasks: [TaskItem]

    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .reverse)])
    private var sessions: [FocusSession]

    let day: Date

    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastDismissWorkItem: DispatchWorkItem?

    private enum DateRelation {
        case past
        case today
        case future
    }

    private struct RitualSummary {
        let total: Int
        let completed: Int

        var isComplete: Bool {
            total > 0 && completed == total
        }
    }

    private var calendar: Calendar { .current }
    private var dayStart: Date { calendar.startOfDay(for: day) }
    private var todayStart: Date { calendar.startOfDay(for: .now) }

    private var dateRelation: DateRelation {
        if calendar.isDate(dayStart, inSameDayAs: todayStart) {
            return .today
        }
        return dayStart > todayStart ? .future : .past
    }

    private var dayTitle: String {
        dayStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var ritualsForDay: [Habit] {
        habits.filter { isHabit($0, activeOn: dayStart) }
    }

    private var completedRitualIDs: Set<UUID> {
        Set(
            completions
                .filter { calendar.isDate($0.day, inSameDayAs: dayStart) }
                .map(\.habitId)
        )
    }

    private var ritualSummary: RitualSummary {
        let completed = ritualsForDay.reduce(0) { count, habit in
            count + (completedRitualIDs.contains(habit.id) ? 1 : 0)
        }
        return RitualSummary(total: ritualsForDay.count, completed: completed)
    }

    private var statusLine: String {
        if dateRelation == .future {
            return "Upcoming"
        }
        if ritualSummary.isComplete {
            return "Rituals complete."
        }
        if ritualSummary.total == 0 {
            return "0 rituals kept"
        }
        return "\(ritualSummary.completed) of \(ritualSummary.total) rituals complete"
    }

    private var tasksForDay: [TaskItem] {
        tasks
            .filter { assignmentDay(for: $0) == dayStart && $0.state != .inbox }
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return lhs.state == .today
                }
                if lhs.priority.sortRank != rhs.priority.sortRank {
                    return lhs.priority.sortRank < rhs.priority.sortRank
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private var focusSecondsForDay: Int {
        let end = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? .distantFuture
        return sessions
            .filter { $0.startedAt >= dayStart && $0.startedAt < end }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        headerCard
                        ritualsCard
                        supportCard
                    }
                    .padding(Theme.Spacing.md)
                }

                if showingToast {
                    Text(toastMessage)
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, Theme.Spacing.cardInset)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.surface, in: Capsule(style: .continuous))
                        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
                        .padding(.bottom, Theme.Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Theme.canvas(for: dayStart).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .animation(.snappy(duration: 0.18), value: showingToast)
        }
        .onDisappear {
            toastDismissWorkItem?.cancel()
            toastDismissWorkItem = nil
        }
    }

    private var headerCard: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dayTitle)
                .font(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.text)

            Spacer(minLength: 0)

            Text(statusLine)
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, Theme.Spacing.xxxs)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.surface2.opacity(0.95))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Theme.textSecondary.opacity(0.16), lineWidth: 0.8)
                }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .primary, cornerRadius: Theme.radiusSmall)
    }

    private var ritualsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Rituals")
                .font(Theme.Typography.sectionLabel)
                .tracking(Theme.Typography.sectionTracking)
                .foregroundStyle(Theme.textSecondary.opacity(0.86))

            if ritualsForDay.isEmpty {
                Text("No rituals for this day.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: Theme.Spacing.xxs) {
                    ForEach(ritualsForDay) { habit in
                        ritualRow(for: habit)
                    }
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .primary, cornerRadius: Theme.radiusSmall)
    }

    private func ritualRow(for habit: Habit) -> some View {
        let isCompleted = completedRitualIDs.contains(habit.id)
        let isPast = dateRelation == .past

        return Button {
            handleRitualTap(habit, isCompleted: isCompleted)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : (dateRelation == .future ? "circle.dashed" : "circle"))
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary.opacity(dateRelation == .future ? 0.52 : 0.74))

                Text(habit.title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(isCompleted ? "Done" : "Not done")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.84))
            }
            .padding(.vertical, Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface2.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.textSecondary.opacity(0.10), lineWidth: 0.8)
            }
            .opacity(isPast ? 0.88 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Execution / Support")
                .font(Theme.Typography.sectionLabel)
                .tracking(Theme.Typography.sectionTracking)
                .foregroundStyle(Theme.textSecondary.opacity(0.8))

            if tasksForDay.isEmpty {
                Text("No tasks assigned.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: Theme.Spacing.xxs) {
                    ForEach(tasksForDay) { task in
                        taskRow(for: task)
                    }
                }
            }

            if focusSecondsForDay > 0 {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "timer")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.72))
                    Text("Focus: \(formatMinutes(focusSecondsForDay))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, Theme.Spacing.xxxs)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private func taskRow(for task: TaskItem) -> some View {
        let isCompleted = task.state == .completed
        let canComplete = dateRelation == .today && !isCompleted

        return HStack(spacing: Theme.Spacing.sm) {
            if canComplete {
                Button {
                    complete(task)
                } label: {
                    Image(systemName: "circle")
                        .font(Theme.Typography.iconCompact)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(isCompleted ? Theme.accent.opacity(0.72) : Theme.textSecondary.opacity(0.6))
            }

            Text(task.title)
                .font(Theme.Typography.itemTitle)
                .foregroundStyle(Theme.textSecondary.opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: 0)

            if task.priority == .high {
                Text("Focus")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.74))
            } else if isCompleted {
                Text("Done")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.74))
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface.opacity(0.7))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.textSecondary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func handleRitualTap(_ habit: Habit, isCompleted: Bool) {
        switch dateRelation {
        case .future:
            showToast("Rituals can be completed on the day.")
        case .past:
            return
        case .today:
            withAnimation(.snappy(duration: 0.16)) {
                if isCompleted {
                    habit.uncompleteToday()
                    removeCompletionRecord(for: habit.id)
                } else {
                    habit.completeToday()
                    ensureCompletionRecord(for: habit.id)
                }
            }
            try? modelContext.save()
        }
    }

    private func complete(_ task: TaskItem) {
        guard dateRelation == .today, task.state == .today else { return }
        withAnimation(.snappy(duration: 0.16)) {
            task.state = .completed
            task.completedAt = .now
        }
        try? modelContext.save()
    }

    private func ensureCompletionRecord(for habitID: UUID) {
        guard !completions.contains(where: { $0.habitId == habitID && calendar.isDate($0.day, inSameDayAs: todayStart) }) else {
            return
        }
        modelContext.insert(HabitCompletion(habitId: habitID, day: todayStart))
    }

    private func removeCompletionRecord(for habitID: UUID) {
        for completion in completions where completion.habitId == habitID && calendar.isDate(completion.day, inSameDayAs: todayStart) {
            modelContext.delete(completion)
        }
    }

    private func isHabit(_ habit: Habit, activeOn day: Date) -> Bool {
        RitualAnalytics.isHabit(
            habit,
            activeOn: day,
            today: todayStart,
            pausePeriods: pausePeriods,
            calendar: calendar
        )
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

    private func showToast(_ message: String) {
        toastDismissWorkItem?.cancel()
        toastMessage = message

        withAnimation(.snappy(duration: 0.18)) {
            showingToast = true
        }

        let work = DispatchWorkItem {
            withAnimation(.snappy(duration: 0.18)) {
                showingToast = false
            }
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: work)
    }
}

struct MonthYearPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedMonthStart: Date
    let minYear: Int
    let maxYear: Int
    let onSelect: (Date) -> Void

    @State private var selectedMonth: Int
    @State private var selectedYear: Int

    private var calendar: Calendar { .current }

    init(
        selectedMonthStart: Date,
        minYear: Int,
        maxYear: Int,
        onSelect: @escaping (Date) -> Void
    ) {
        self.selectedMonthStart = selectedMonthStart
        self.minYear = minYear
        self.maxYear = maxYear
        self.onSelect = onSelect

        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthStart)
        _selectedMonth = State(initialValue: components.month ?? Calendar.current.component(.month, from: .now))
        _selectedYear = State(initialValue: components.year ?? Calendar.current.component(.year, from: .now))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.md) {
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(calendar.monthSymbols[month - 1]).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("Year", selection: $selectedYear) {
                        ForEach(minYear...maxYear, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .frame(maxHeight: 190)
                .clipped()

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .navigationTitle("Jump to Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard let month = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) else {
                            dismiss()
                            return
                        }
                        onSelect(calendar.startOfDay(for: month))
                        dismiss()
                    }
                }
            }
        }
    }
}
