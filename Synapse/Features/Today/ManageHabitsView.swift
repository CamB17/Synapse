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
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Add habit...", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(add)

                    Button {
                        add()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                List {
                    Section(header: Text("Active")) {
                        ForEach(activeHabits) { habit in
                            HStack {
                                Text(habit.title)
                                Spacer()
                                Text("\(habit.currentStreak)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
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

    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            let habit = activeHabits[idx]
            modelContext.delete(habit)
        }
        do {
            try modelContext.save()
        } catch {
            print("Habit delete failed: \(error)")
        }
    }
}
