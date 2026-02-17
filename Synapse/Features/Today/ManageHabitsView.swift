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
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        TextField("Add habit...", text: $text)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.text)
                            .submitLabel(.done)
                            .onSubmit(add)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Theme.surface,
                                in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                            )
                            .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)

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
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTIVE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .tracking(0.8)
                            .padding(.horizontal, 16)

                        if activeHabits.isEmpty {
                            Text("No habits yet. Add your first daily anchor.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Theme.surface,
                                    in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                                )
                                .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
                                .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(activeHabits.enumerated()), id: \.element.id) { index, habit in
                                    HStack(spacing: 12) {
                                        Text(habit.title)
                                            .font(.system(size: 17, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.text)
                                            .lineLimit(1)

                                        Spacer(minLength: 8)

                                        Text("\(habit.currentStreak)")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                                    .padding(.vertical, 12)

                                    if index < activeHabits.count - 1 {
                                        Divider()
                                            .padding(.leading, 14)
                                    }
                                }
                            }
                            .background(
                                Theme.surface,
                                in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                            )
                            .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
                            .padding(.horizontal, 16)
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
