import SwiftUI
import SwiftData

struct HabitCompletionSnapshot {
    let completedBefore: Int
    let completedAfter: Int
    let activeCount: Int
    let didComplete: Bool
}

struct HabitBlock: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @State private var showingManage = false
    @State private var pulseId: UUID?
    @State private var sparkleId: UUID?
    @State private var showCompletedRituals = false
    var onCompletionStateChange: ((HabitCompletionSnapshot) -> Void)? = nil

    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    private var pendingHabits: [Habit] {
        activeHabits.filter { !$0.completedToday }
    }

    private var hasCompletedAll: Bool {
        !activeHabits.isEmpty && pendingHabits.isEmpty
    }

    private var showsOverflowCue: Bool {
        activeHabits.count > 3
    }

    private var overflowCount: Int {
        max(0, activeHabits.count - 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(icon: "leaf", title: "Rituals")

                Spacer()

                Button {
                    showingManage = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(Theme.Typography.iconMedium)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Manage habits")
            }

            if hasCompletedAll {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        showCompletedRituals.toggle()
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "checkmark.circle")
                            .font(Theme.Typography.iconSmall)
                            .foregroundStyle(Theme.success)

                        Text(showCompletedRituals ? "Hide completed rituals" : "All rituals complete")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Spacer(minLength: 0)

                        Image(systemName: showCompletedRituals ? "chevron.up" : "chevron.down")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, Theme.Spacing.xxxs)
            }

            if activeHabits.isEmpty {
                Text("Add a few daily anchors.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, Theme.Spacing.xxs)
            } else {
                if !hasCompletedAll || showCompletedRituals {
                    ZStack(alignment: .bottom) {
                        ScrollView(.vertical) {
                            VStack(spacing: Theme.Spacing.hairline) {
                                ForEach(activeHabits) { habit in
                                    HabitRow(
                                        title: habit.title,
                                        isCompletedToday: habit.completedToday,
                                        showSparkle: sparkleId == habit.id
                                    ) {
                                        toggle(habit)
                                    }
                                    .opacity(habit.completedToday ? 0.72 : 1.0)
                                    .scaleEffect(pulseId == habit.id ? 1.01 : 1.0)
                                    .animation(.snappy(duration: 0.16), value: pulseId)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)

                        if showsOverflowCue {
                            LinearGradient(
                                colors: [Theme.surface2.opacity(0), Theme.surface2.opacity(0.96)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 34)
                            .allowsHitTesting(false)

                            HStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: "chevron.down")
                                    .font(Theme.Typography.iconSmall)
                                Text("Scroll for \(overflowCount) more")
                                    .font(Theme.Typography.caption.weight(.semibold))
                            }
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.bottom, Theme.Spacing.xxxs)
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(maxHeight: showsOverflowCue ? 180 : .infinity)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .surfaceCard(style: .secondary)
        .sheet(isPresented: $showingManage) {
            ManageHabitsView()
        }
    }

    private func toggle(_ habit: Habit) {
        let wasCompleted = habit.completedToday
        let activeCount = activeHabits.count
        let completedBefore = activeHabits.filter(\.completedToday).count
        let completedAfter = wasCompleted
            ? max(0, completedBefore - 1)
            : min(activeCount, completedBefore + 1)
        let haptic = UIImpactFeedbackGenerator(style: wasCompleted ? .soft : .light)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.18)) {
            if wasCompleted {
                habit.uncompleteToday()
                sparkleId = nil
            } else {
                habit.completeToday()
                sparkleId = habit.id
            }
            pulseId = wasCompleted ? nil : habit.id
        }

        do {
            try modelContext.save()
        } catch {
            print("Habit save failed: \(error)")
        }

        onCompletionStateChange?(
            HabitCompletionSnapshot(
                completedBefore: completedBefore,
                completedAfter: completedAfter,
                activeCount: activeCount,
                didComplete: !wasCompleted
            )
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if pulseId == habit.id { pulseId = nil }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if sparkleId == habit.id { sparkleId = nil }
        }
        if hasCompletedAll {
            showCompletedRituals = false
        }
    }
}
