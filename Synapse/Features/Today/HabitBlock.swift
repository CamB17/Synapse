import SwiftUI
import SwiftData

struct HabitBlock: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @State private var showingManage = false
    @State private var pulseId: UUID?

    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    private var pendingHabits: [Habit] {
        activeHabits.filter { !$0.completedToday }
    }

    private var reminderText: String {
        guard let first = pendingHabits.first else { return "" }
        let remaining = pendingHabits.count - 1
        if remaining > 0 {
            return "Don't forget: \(first.title) +\(remaining) more"
        }
        return "Don't forget: \(first.title)"
    }
    
    private var showHabitsCompleteLine: Bool {
        activeHabits.count >= 2 && pendingHabits.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("HABITS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Spacer()

                Button {
                    showingManage = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Manage habits")
            }

            if !pendingHabits.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(reminderText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 2)
            } else if showHabitsCompleteLine {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("Habits complete today.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 2)
            }

            if activeHabits.isEmpty {
                Text("Add a few daily anchors.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(activeHabits.prefix(6)) { habit in
                        HabitRow(
                            title: habit.title,
                            streakText: streakText(for: habit),
                            isCompletedToday: habit.completedToday
                        ) {
                            toggle(habit)
                        }
                        .opacity(habit.completedToday ? 0.65 : 1.0)
                        .scaleEffect(pulseId == habit.id ? 1.01 : 1.0)
                        .animation(.snappy(duration: 0.16), value: pulseId)
                    }

                    if activeHabits.count > 6 {
                        Text("+ \(activeHabits.count - 6) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $showingManage) {
            ManageHabitsView()
        }
    }

    private func toggle(_ habit: Habit) {
        let wasCompleted = habit.completedToday
        let haptic = UIImpactFeedbackGenerator(style: wasCompleted ? .soft : .light)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.18)) {
            if wasCompleted {
                habit.uncompleteToday()
            } else {
                habit.completeToday()
            }
            pulseId = wasCompleted ? nil : habit.id
        }

        do {
            try modelContext.save()
        } catch {
            print("Habit save failed: \(error)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if pulseId == habit.id { pulseId = nil }
        }
    }

    private func streakText(for habit: Habit) -> String {
        if habit.currentStreak <= 0 {
            return "Not started"
        }
        if habit.completedToday {
            return "\(habit.currentStreak) day streak"
        }

        if let last = habit.lastCompletedDate,
           !Calendar.current.isDateInYesterday(last) {
            return "Paused at \(habit.currentStreak) days"
        }

        return "\(habit.currentStreak) day streak"
    }
}
