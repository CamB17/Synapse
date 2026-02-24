import SwiftUI
import SwiftData

struct HabitEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let habit: Habit?
    let defaultSortOrder: Int
    let onSaved: ((Habit) -> Void)?

    @State private var title: String
    @State private var frequency: HabitFrequency
    @State private var timeOfDay: TaskPartOfDay
    @State private var selectedWeekdays: Set<Int>

    private var calendar: Calendar { .current }

    init(habit: Habit? = nil, defaultSortOrder: Int = 0, onSaved: ((Habit) -> Void)? = nil) {
        self.habit = habit
        self.defaultSortOrder = defaultSortOrder
        self.onSaved = onSaved

        let initialFrequency = habit?.frequency ?? .daily
        let initialTimeOfDay = habit?.timeOfDay ?? .anytime
        let defaultWeekday = Calendar.current.component(.weekday, from: .now)
        let initialDays = habit?.scheduledWeekdays ?? [defaultWeekday]

        _title = State(initialValue: habit?.title ?? "")
        _frequency = State(initialValue: initialFrequency)
        _timeOfDay = State(initialValue: initialTimeOfDay)
        _selectedWeekdays = State(initialValue: initialDays.isEmpty ? [defaultWeekday] : initialDays)
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    titleCard
                    frequencyCard
                    timeCard
                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)
            }
            .navigationTitle(habit == nil ? "Add Habit" : "Edit Habit")
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
                    Button("Save") {
                        save()
                    }
                    .tint(Theme.accent)
                    .disabled(saveDisabled)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Name")
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
                Text(HabitFrequency.daily.displayLabel).tag(HabitFrequency.daily)
                Text(HabitFrequency.weekly.displayLabel).tag(HabitFrequency.weekly)
                Text(HabitFrequency.custom.displayLabel).tag(HabitFrequency.custom)
            }
            .pickerStyle(.segmented)

            if frequency == .weekly || frequency == .custom {
                weekdayPicker
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
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

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Time")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Picker("Time", selection: $timeOfDay) {
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

    private func weekdayChip(_ day: Int) -> some View {
        let isSelected = selectedWeekdays.contains(day)

        return Button {
            withAnimation(.snappy(duration: 0.16)) {
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

    private var saveDisabled: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if (frequency == .weekly || frequency == .custom) && selectedWeekdays.isEmpty { return true }
        return false
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

        if let habit {
            habit.title = trimmed
            habit.frequency = frequency
            habit.timeOfDay = timeOfDay
            habit.scheduledWeekdays = normalizedWeekdays
        } else {
            let newHabit = Habit(
                title: trimmed,
                frequency: frequency,
                timeOfDay: timeOfDay,
                scheduledWeekdays: normalizedWeekdays,
                sortOrder: defaultSortOrder
            )
            modelContext.insert(newHabit)
            onSaved?(newHabit)
        }

        if let habit {
            onSaved?(habit)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Habit save error: \(error)")
        }
    }
}
