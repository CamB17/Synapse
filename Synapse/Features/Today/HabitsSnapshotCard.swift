import SwiftUI
import UIKit

private enum TodayHaptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct HabitsSnapshotCard: View {
    struct Item: Identifiable {
        let id: UUID
        let title: String
        let isComplete: Bool
        let trend: [Bool]
        let todayTrendIndex: Int?
        let streakLabel: String?
    }

    let completedCount: Int
    let totalCount: Int
    let items: [Item]
    let onToggleHabit: (UUID) -> Void
    let onManage: () -> Void
    let onAddHabit: () -> Void
    let onViewAll: () -> Void

    private let visibleCount = 5

    private var visibleItems: [Item] {
        Array(items.prefix(visibleCount))
    }

    private var hasOverflow: Bool {
        items.count > visibleCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            header

            if visibleItems.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text("No habits yet")
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                    Text("Add a habit to start momentum.")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.bottom, Theme.Spacing.xxxs)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleItems) { item in
                        habitRow(item)
                        if item.id != visibleItems.last?.id {
                            Divider()
                                .overlay(Theme.text.opacity(0.08))
                                .padding(.leading, 30)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xxxs)
            }

            if hasOverflow {
                Button {
                    TodayHaptics.light()
                    onViewAll()
                } label: {
                    HStack(spacing: Theme.Spacing.xxxs) {
                        Text("View all habits")
                        Image(systemName: "chevron.right")
                            .font(Theme.Typography.caption.weight(.semibold))
                    }
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(TodayPressableButtonStyle())
            }
        }
        .padding(.horizontal, 2)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("Habits")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.text)

            Text("\(completedCount)/\(max(totalCount, 0))")
                .font(Theme.Typography.metricValue)
                .monospacedDigit()
                .foregroundStyle(Theme.accent)

            Spacer(minLength: 0)

            textAction(title: "Manage", action: onManage)
            textAction(title: "Add", action: onAddHabit)
        }
    }

    private func textAction(title: String, action: @escaping () -> Void) -> some View {
        Button {
            TodayHaptics.light()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.xxxs) {
                Text(title)
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption.weight(.semibold))
            }
            .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .buttonStyle(TodayPressableButtonStyle())
    }

    private func habitRow(_ item: Item) -> some View {
        Button {
            TodayHaptics.light()
            onToggleHabit(item.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(item.isComplete ? Theme.accent : Theme.textSecondary)

                Text(item.title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Spacer(minLength: 0)

                HabitMicroTrendView(values: item.trend, todayIndex: item.todayTrendIndex)

                if let streakLabel = item.streakLabel {
                    Text(streakLabel)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(TodayPressableButtonStyle())
    }
}
