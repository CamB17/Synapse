import SwiftUI
import SwiftData

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let task: TaskItem

    @State private var title: String
    @State private var assignedDate: Date
    @State private var partOfDay: TaskPartOfDay
    @State private var priority: TaskPriority
    @State private var repeatRule: TaskRepeatRule
    @State private var customRepeatText: String
    @State private var markCompleted: Bool

    private var calendar: Calendar { .current }

    init(task: TaskItem) {
        self.task = task

        let assigned = task.assignedDate ?? task.createdAt
        _title = State(initialValue: task.title)
        _assignedDate = State(initialValue: Calendar.current.startOfDay(for: assigned))
        _partOfDay = State(initialValue: task.partOfDay)
        _priority = State(initialValue: task.priority)
        _repeatRule = State(initialValue: task.repeatRule)
        _customRepeatText = State(initialValue: task.repeatCustomValue ?? "")
        _markCompleted = State(initialValue: task.state == .completed)
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        titleCard
                        dateCard
                        timeCard
                        priorityCard
                        repeatCard
                        statusCard
                        Spacer(minLength: 0)
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.lg)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Task")
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

            TextField("Task title", text: $title)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Date")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            DatePicker("Date", selection: $assignedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Time")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Picker("Time", selection: $partOfDay) {
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

    private var priorityCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Role")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Picker("Task role", selection: $priority) {
                Text(TaskPriority.high.displayLabel).tag(TaskPriority.high)
                Text(TaskPriority.medium.displayLabel).tag(TaskPriority.medium)
                Text(TaskPriority.low.displayLabel).tag(TaskPriority.low)
            }
            .pickerStyle(.segmented)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Repeat")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Picker("Repeat", selection: $repeatRule) {
                Text("No repeat").tag(TaskRepeatRule.none)
                Text("Daily").tag(TaskRepeatRule.daily)
                Text("Weekly").tag(TaskRepeatRule.weekly)
                Text("Monthly").tag(TaskRepeatRule.monthly)
                Text("Yearly").tag(TaskRepeatRule.yearly)
                Text("Custom").tag(TaskRepeatRule.custom)
            }
            .pickerStyle(.menu)

            if repeatRule == .custom {
                TextField("Custom repeat rule", text: $customRepeatText)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Status")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Toggle(isOn: $markCompleted) {
                Text(markCompleted ? "Completed" : "Scheduled")
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)
            }
            .tint(Theme.accent)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var saveDisabled: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if repeatRule == .custom && customRepeatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        task.title = trimmed
        task.assignedDate = calendar.startOfDay(for: assignedDate)
        task.partOfDay = partOfDay
        task.priority = priority
        task.repeatRule = repeatRule

        if repeatRule == .custom {
            task.repeatCustomValue = customRepeatText.trimmingCharacters(in: .whitespacesAndNewlines)
            task.repeatAnchorDate = calendar.startOfDay(for: assignedDate)
        } else if repeatRule == .none {
            task.repeatCustomValue = nil
            task.repeatAnchorDate = nil
        } else {
            task.repeatCustomValue = nil
            task.repeatAnchorDate = calendar.startOfDay(for: assignedDate)
        }

        if markCompleted {
            task.state = .completed
            if task.completedAt == nil {
                task.completedAt = .now
            }
        } else {
            task.state = .today
            task.completedAt = nil
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Task save error: \(error)")
        }
    }
}
