import SwiftUI
import SwiftData

struct ManageHabitsView: View {
    var title: String = "Habits"
    var showsDoneButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @State private var text: String = ""
    @State private var editingHabitID: UUID?
    @State private var editingTitle: String = ""
    @FocusState private var isEditTitleFocused: Bool
    
    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
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

                                        Text("\(habit.currentStreak)")
                                            .font(Theme.Typography.bodyMedium.weight(.semibold))
                                            .foregroundStyle(Theme.textSecondary)
                                            .monospacedDigit()

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
                                                delete(habit)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
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

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle(title)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onChange(of: editingHabitID) { _, newValue in
                isEditTitleFocused = newValue != nil
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Habit(title: trimmed))
        text = ""
        do {
            try modelContext.save()
        } catch {
            print("Habit save failed: \(error)")
        }
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
            print("Habit edit failed: \(error)")
        }
    }

    private func delete(_ habit: Habit) {
        modelContext.delete(habit)
        do {
            try modelContext.save()
        } catch {
            print("Habit delete failed: \(error)")
        }
    }
}
