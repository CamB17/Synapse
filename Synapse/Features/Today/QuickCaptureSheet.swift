import SwiftUI
import SwiftData

struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text: String = ""
    @State private var assignedDate: Date
    @State private var partOfDay: TaskPartOfDay = .anytime
    @State private var repeatRule: TaskRepeatRule = .none
    @State private var customRepeatText = ""
    @State private var priority: TaskPriority = .medium
    @State private var voiceSeedText = ""
    @StateObject private var voiceCapture = VoiceCaptureController()
    @FocusState private var titleFieldFocused: Bool

    let placeholder: String
    let canAssignDefaultDay: Bool
    let defaultAssignmentDay: Date
    let onAdded: ((TaskItem, Bool) -> Void)?

    private var calendar: Calendar { .current }
    private var assignedDayStart: Date { calendar.startOfDay(for: assignedDate) }
    private var repeatOptions: [TaskRepeatRule] {
        [.none, .daily, .weekly, .monthly, .yearly, .custom]
    }
    private var isDefaultDaySelection: Bool {
        calendar.isDate(assignedDayStart, inSameDayAs: defaultAssignmentDay)
    }

    init(
        placeholder: String,
        canAssignDefaultDay: Bool,
        defaultAssignmentDay: Date,
        onAdded: ((TaskItem, Bool) -> Void)?
    ) {
        self.placeholder = placeholder
        self.canAssignDefaultDay = canAssignDefaultDay
        self.defaultAssignmentDay = Calendar.current.startOfDay(for: defaultAssignmentDay)
        self.onAdded = onAdded
        _assignedDate = State(initialValue: Calendar.current.startOfDay(for: defaultAssignmentDay))
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    titleInput

                    if let error = voiceCapture.errorMessage {
                        Text(error)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, Theme.Spacing.xs)
                    }

                    partOfDaySection

                    dateSection

                    repeatSection

                    prioritySection

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.md)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        titleFieldFocused = false
                    }
                )
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Theme.accent)
                        .buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .tint(Theme.accent)
                        .buttonStyle(.plain)
                        .disabled(addDisabled)
                }
            }
            .onDisappear {
                voiceCapture.stop()
            }
        }
    }

    private var titleInput: some View {
        HStack(spacing: Theme.Spacing.xs) {
            TextField(placeholder, text: $text)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($titleFieldFocused)
                .onSubmit {
                    titleFieldFocused = false
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 22)

            Button {
                toggleVoiceCapture()
            } label: {
                Image(systemName: voiceCapture.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(Theme.Typography.iconXL)
                    .foregroundStyle(voiceCapture.isRecording ? Theme.accent2 : Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(voiceCapture.isRecording ? "Stop voice capture" : "Start voice capture")
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .frame(minHeight: 52)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
        .padding(.top, Theme.Spacing.xs)
    }

    private var partOfDaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Time")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Picker("Time", selection: $partOfDay) {
                Text("Anytime").tag(TaskPartOfDay.anytime)
                Text("Morning").tag(TaskPartOfDay.morning)
                Text("Afternoon").tag(TaskPartOfDay.afternoon)
                Text("Evening").tag(TaskPartOfDay.evening)
            }
            .pickerStyle(.segmented)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Date")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            DatePicker("Date", selection: $assignedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

            if isDefaultDaySelection && !canAssignDefaultDay {
                Text("This day is full (max 5). Pick another date.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Repeat")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.xs)],
                alignment: .leading,
                spacing: Theme.Spacing.xs
            ) {
                ForEach(repeatOptions, id: \.self) { option in
                    repeatPill(option)
                }
            }

            if repeatRule == .custom {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "slider.horizontal.3")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)

                    TextField("Custom repeat rule", text: $customRepeatText)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.text)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
            }

            if repeatRule == .daily || repeatRule == .weekly || repeatRule == .monthly || repeatRule == .yearly {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "calendar")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Starts \(assignedDayStart.formatted(.dateTime.month(.abbreviated).day().year())).")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.top, Theme.Spacing.xxxs)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var prioritySection: some View {
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

    private var addDisabled: Bool {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if isDefaultDaySelection && !canAssignDefaultDay { return true }
        if repeatRule == .custom && customRepeatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return false
    }

    private func add() {
        voiceCapture.stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isDefaultDaySelection || canAssignDefaultDay else { return }

        let repeatAnchor: Date? = {
            switch repeatRule {
            case .daily, .weekly, .monthly, .yearly:
                return assignedDayStart
            case .custom:
                return assignedDayStart
            case .none:
                return nil
            }
        }()

        let task = TaskItem(
            title: trimmed,
            state: .today,
            priority: priority,
            partOfDay: partOfDay,
            repeatRule: repeatRule,
            repeatCustomValue: repeatRule == .custom ? customRepeatText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            assignedDate: assignedDayStart,
            repeatAnchorDate: repeatAnchor
        )

        modelContext.insert(task)
        try? modelContext.save()
        onAdded?(task, true)
        dismiss()
    }

    private func toggleVoiceCapture() {
        voiceSeedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        voiceCapture.toggle { spoken in
            text = mergedText(base: voiceSeedText, spoken: spoken)
        }
    }

    private func mergedText(base: String, spoken: String) -> String {
        let cleanedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSpoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSpoken.isEmpty else { return cleanedBase }
        guard !cleanedBase.isEmpty else { return cleanedSpoken }
        return "\(cleanedBase) \(cleanedSpoken)"
    }

    private func repeatPill(_ option: TaskRepeatRule) -> some View {
        let isSelected = repeatRule == option
        return Button {
            withAnimation(.snappy(duration: 0.16)) {
                repeatRule = option
            }
        } label: {
            Text(repeatLabel(option))
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Theme.accent.opacity(0.14) : Theme.surface2)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Theme.accent.opacity(0.45) : Theme.textSecondary.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func repeatLabel(_ option: TaskRepeatRule) -> String {
        switch option {
        case .none: return "No repeat"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        }
    }
}
