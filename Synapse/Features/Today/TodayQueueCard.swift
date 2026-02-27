import SwiftUI
import UIKit

private enum TodayHaptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct TodayQueueCard: View {
    struct Item: Identifiable {
        let id: UUID
        let title: String
        let metadata: String?
        let estimateLabel: String?
        let isCarryOver: Bool
    }

    let upNext: [Item]
    let later: [Item]
    let carryOver: [Item]
    let filterOptions: [String]
    let selectedFilter: String
    let emptyStateTitle: String
    let emptyStateSubtitle: String
    let onSelectFilter: (String) -> Void
    let onTaskTap: (UUID) -> Void
    let onCompleteTask: (UUID) -> Void
    let onStartFocusTask: (UUID) -> Void
    let onQuickAdd: () -> Void
    let onViewAll: () -> Void

    private var hasAnyTasks: Bool {
        !upNext.isEmpty || !later.isEmpty || !carryOver.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header
                .padding(.horizontal, Theme.Spacing.cardInset)
                .padding(.top, Theme.Spacing.cardInset)

            if hasAnyTasks {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if !upNext.isEmpty {
                        taskSection(title: "UP NEXT", items: upNext)
                    }

                    if !later.isEmpty {
                        taskSection(title: "LATER", items: later)
                    }

                    if !carryOver.isEmpty {
                        taskSection(title: "CARRY-OVER", items: carryOver)
                    }
                }
                .padding(.horizontal, Theme.Spacing.cardInset)
                .padding(.bottom, Theme.Spacing.cardInset)
            } else {
                emptyState
                    .padding(.horizontal, Theme.Spacing.cardInset)
                    .padding(.bottom, Theme.Spacing.cardInset)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface.opacity(0.95))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.text.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, y: 5)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("Tasks")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.text)

            chipsRow
                .frame(maxWidth: .infinity, alignment: .leading)

            textAction(title: "Quick add", action: onQuickAdd)
            textAction(title: "View all", action: onViewAll)
        }
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(filterOptions, id: \.self) { option in
                    let isSelected = option == selectedFilter
                    Button {
                        TodayHaptics.light()
                        onSelectFilter(option)
                    } label: {
                        Text(option)
                            .font(Theme.Typography.chipLabel)
                            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Theme.accent.opacity(0.14) : Theme.surface2.opacity(0.82))
                            )
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(
                                        isSelected ? Theme.accent.opacity(0.30) : Theme.text.opacity(0.09),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(TodayPressableButtonStyle())
                }
            }
        }
        .frame(height: 24)
    }

    private func taskSection(
        title: String,
        items: [Item]
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.labelCaps)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    queueRow(item)

                    if index < items.count - 1 {
                        Divider()
                            .overlay(Theme.text.opacity(0.10))
                            .padding(.leading, 32)
                    }
                }
            }
        }
    }

    private func queueRow(_ item: Item) -> some View {
        HStack(spacing: 10) {
            Button {
                TodayHaptics.light()
                onCompleteTask(item.id)
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary.opacity(0.9))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(TodayPressableButtonStyle())

            Button {
                TodayHaptics.light()
                onTaskTap(item.id)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(Theme.Typography.itemTitle)
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)

                    if let metadata = item.metadata {
                        Text(metadata)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(TodayPressableButtonStyle())

            Button {
                TodayHaptics.light()
                onStartFocusTask(item.id)
            } label: {
                HStack(spacing: Theme.Spacing.xxxs) {
                    if let estimateLabel = item.estimateLabel {
                        Text(estimateLabel)
                            .font(Theme.Typography.caption)
                            .monospacedDigit()
                    }
                    Image(systemName: "chevron.right")
                        .font(Theme.Typography.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(TodayPressableButtonStyle())
            .accessibilityLabel("Start focus")
        }
        .padding(.horizontal, Theme.Spacing.xxxs)
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(emptyStateTitle)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
            Text(emptyStateSubtitle)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}
