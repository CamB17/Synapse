import SwiftUI
import SwiftData

struct ManageHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @State private var text: String = ""
    
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
                                .font(.system(size: 22, weight: .semibold))
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
                                        Text(habit.title)
                                            .font(Theme.Typography.itemTitle)
                                            .foregroundStyle(Theme.text)
                                            .lineLimit(1)

                                        Spacer(minLength: Theme.Spacing.xs)

                                        Text("\(habit.currentStreak)")
                                            .font(Theme.Typography.bodyMedium.weight(.semibold))
                                            .foregroundStyle(Theme.textSecondary)
                                            .monospacedDigit()

                                        Button {
                                            delete(habit)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remove \(habit.title)")
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, Theme.Spacing.sm)

                                    if index < activeHabits.count - 1 {
                                        Divider()
                                            .padding(.leading, 14)
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
            .navigationTitle("Habits")
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .tint(Theme.accent)
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

    private func delete(_ habit: Habit) {
        modelContext.delete(habit)
        do {
            try modelContext.save()
        } catch {
            print("Habit delete failed: \(error)")
        }
    }
}
