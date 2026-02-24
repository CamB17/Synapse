import SwiftUI
import SwiftData

struct ManageHabitsView: View {
    var title: String = "Habits"
    var showsDoneButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]
    @Query(sort: [SortDescriptor(\HabitPausePeriod.startDay, order: .reverse)])
    private var pausePeriods: [HabitPausePeriod]

    @State private var text: String = ""
    @State private var voiceSeedText = ""
    @State private var editingHabitID: UUID?
    @State private var editingTitle: String = ""
    @FocusState private var isEditTitleFocused: Bool
    @StateObject private var voiceCapture = VoiceCaptureController()
    
    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    private var pausedHabits: [Habit] {
        habits.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                VStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.xs) {
                        TextField("Add habit...", text: $text)
                            .font(Theme.Typography.bodyMedium)
                            .foregroundStyle(Theme.text)
                            .submitLabel(.done)
                            .onSubmit(add)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 10)
                            .surfaceCard()

                        Button {
                            toggleVoiceCapture()
                        } label: {
                            Image(systemName: voiceCapture.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                .font(Theme.Typography.iconXL)
                                .foregroundStyle(voiceCapture.isRecording ? Theme.accent2 : Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(voiceCapture.isRecording ? "Stop voice capture" : "Start voice capture")

                        Button {
                            add()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(Theme.Typography.iconXL)
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)

                    if let error = voiceCapture.errorMessage {
                        Text(error)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.md)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        SectionLabel(icon: "leaf", title: "Active")
                            .padding(.horizontal, Theme.Spacing.md)

                        if activeHabits.isEmpty {
                            EmptyStatePanel(
                                symbol: "leaf",
                                title: "No habits yet.",
                                subtitle: "Add your first daily anchor."
                            )
                            .padding(.horizontal, Theme.Spacing.md)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(activeHabits.enumerated()), id: \.element.id) { index, habit in
                                    HStack(spacing: Theme.Spacing.sm) {
                                        if editingHabitID == habit.id {
                                            TextField("Habit name", text: $editingTitle)
                                                .font(Theme.Typography.itemTitle)
                                                .foregroundStyle(Theme.text)
                                                .submitLabel(.done)
                                                .focused($isEditTitleFocused)
                                                .onSubmit { commitEdit(for: habit) }
                                        } else {
                                            Text(habit.title)
                                                .font(Theme.Typography.itemTitle)
                                                .foregroundStyle(Theme.text)
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: Theme.Spacing.xs)

                                        if editingHabitID == habit.id {
                                            Button {
                                                cancelEdit()
                                            } label: {
                                                Image(systemName: "xmark.circle")
                                                    .font(Theme.Typography.iconCard)
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Cancel editing \(habit.title)")

                                            Button {
                                                commitEdit(for: habit)
                                            } label: {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(Theme.Typography.iconCard)
                                                    .foregroundStyle(Theme.accent)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Save \(habit.title)")
                                        } else {
                                            Button {
                                                beginEdit(for: habit)
                                            } label: {
                                                Image(systemName: "pencil.circle")
                                                    .font(Theme.Typography.iconCard)
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Edit \(habit.title)")

                                            Button {
                                                pause(habit)
                                            } label: {
                                                Image(systemName: "pause.circle")
                                                    .font(Theme.Typography.iconCard)
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Pause \(habit.title)")

                                            Button {
                                                delete(habit)
                                            } label: {
                                                Image(systemName: "trash.circle")
                                                    .font(Theme.Typography.iconCard)
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Remove \(habit.title)")
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.cardInset)
                                    .padding(.vertical, Theme.Spacing.sm)

                                    if index < activeHabits.count - 1 {
                                        Divider()
                                            .padding(.leading, Theme.Spacing.cardInset)
                                    }
                                }
                            }
                            .surfaceCard()
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                    }

                    if !pausedHabits.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            SectionLabel(icon: "pause.circle", title: "Paused")
                                .padding(.horizontal, Theme.Spacing.md)

                            VStack(spacing: 0) {
                                ForEach(Array(pausedHabits.enumerated()), id: \.element.id) { index, habit in
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Text(habit.title)
                                            .font(Theme.Typography.itemTitle)
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(1)

                                        Spacer(minLength: Theme.Spacing.xs)

                                        Button {
                                            resume(habit)
                                        } label: {
                                            Image(systemName: "play.circle.fill")
                                                .font(Theme.Typography.iconCard)
                                                .foregroundStyle(Theme.accent)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Resume \(habit.title)")

                                        Button {
                                            delete(habit)
                                        } label: {
                                            Image(systemName: "trash.circle")
                                                .font(Theme.Typography.iconCard)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remove \(habit.title)")
                                    }
                                    .padding(.horizontal, Theme.Spacing.cardInset)
                                    .padding(.vertical, Theme.Spacing.sm)

                                    if index < pausedHabits.count - 1 {
                                        Divider()
                                            .padding(.leading, Theme.Spacing.cardInset)
                                    }
                                }
                            }
                            .surfaceCard()
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle(title)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onChange(of: editingHabitID) { _, newValue in
                isEditTitleFocused = newValue != nil
            }
            .onDisappear {
                voiceCapture.stop()
            }
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .tint(Theme.accent)
                    }
                }
            }
        }
    }

    private func add() {
        voiceCapture.stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Habit(title: trimmed))
        text = ""
        do {
            try modelContext.save()
        } catch {
            print("Habit save error: \(error)")
        }
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

    private func beginEdit(for habit: Habit) {
        editingHabitID = habit.id
        editingTitle = habit.title
    }

    private func cancelEdit() {
        editingHabitID = nil
        editingTitle = ""
    }

    private func commitEdit(for habit: Habit) {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelEdit()
            return
        }
        habit.title = trimmed
        cancelEdit()
        do {
            try modelContext.save()
        } catch {
            print("Habit edit error: \(error)")
        }
    }

    private func delete(_ habit: Habit) {
        modelContext.delete(habit)
        for period in pausePeriods where period.habitId == habit.id {
            modelContext.delete(period)
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
        if let period = pausePeriods.first(where: { $0.habitId == habit.id && $0.endDay == nil }) {
            period.endDay = Calendar.current.startOfDay(for: .now)
        }

        do {
            try modelContext.save()
        } catch {
            print("Habit resume error: \(error)")
        }
    }
}
