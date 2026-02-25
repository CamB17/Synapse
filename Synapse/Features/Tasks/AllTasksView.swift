import SwiftData
import SwiftUI

struct AllTasksView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\TaskItem.createdAt, order: .reverse)])
    private var tasks: [TaskItem]

    @State private var query = ""
    @State private var statusFilter: StatusFilter = .all
    @State private var roleFilter: RoleFilter = .all
    @State private var editingTask: TaskItem?

    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case scheduled = "Scheduled"
        case completed = "Completed"

        var id: String { rawValue }
    }

    private enum RoleFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case focus = "Focus"
        case support = "Support"
        case flexible = "Flexible"

        var id: String { rawValue }

        var priority: TaskPriority? {
            switch self {
            case .all:
                return nil
            case .focus:
                return .high
            case .support:
                return .medium
            case .flexible:
                return .low
            }
        }
    }

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }

    private var filteredTasks: [TaskItem] {
        tasks.filter { task in
            if let role = roleFilter.priority, task.priority != role {
                return false
            }

            switch statusFilter {
            case .all:
                break
            case .scheduled:
                if task.state == .completed {
                    return false
                }
            case .completed:
                if task.state != .completed {
                    return false
                }
            }

            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedQuery.isEmpty {
                return task.title.localizedCaseInsensitiveContains(trimmedQuery)
            }

            return true
        }
    }

    private var upcomingGroups: [(date: Date, tasks: [TaskItem])] {
        let grouped = Dictionary(grouping: filteredTasks.filter { task in
            task.state != .completed && assignmentDay(for: task) >= todayStart
        }) { task in
            assignmentDay(for: task)
        }

        return grouped
            .map { day, entries in
                (
                    date: day,
                    tasks: entries.sorted { lhs, rhs in
                        if lhs.priority.sortRank != rhs.priority.sortRank {
                            return lhs.priority.sortRank < rhs.priority.sortRank
                        }
                        return lhs.createdAt < rhs.createdAt
                    }
                )
            }
            .sorted { $0.date < $1.date }
    }

    private var completedGroup: [TaskItem] {
        filteredTasks
            .filter { $0.state == .completed }
            .sorted { lhs, rhs in
                (lhs.completedAt ?? lhs.createdAt) > (rhs.completedAt ?? rhs.createdAt)
            }
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        searchField
                        filterControls

                        if upcomingGroups.isEmpty && completedGroup.isEmpty {
                            EmptyStatePanel(
                                symbol: "checklist",
                                title: "No matching tasks.",
                                subtitle: "Adjust search or filters to broaden results."
                            )
                        } else {
                            upcomingSection
                            completedSection
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("All Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(Theme.accent)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(task: task)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            TextField("Search tasks", text: $query)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var filterControls: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Role", selection: $roleFilter) {
                ForEach(RoleFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if !upcomingGroups.isEmpty {
                SectionLabel(icon: "calendar", title: "Upcoming")

                ForEach(upcomingGroups, id: \.date) { group in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(group.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)

                        ForEach(group.tasks) { task in
                            taskRow(task)
                        }
                    }
                    .padding(Theme.Spacing.cardInset)
                    .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if !completedGroup.isEmpty {
                SectionLabel(icon: "checkmark.circle", title: "Completed")

                VStack(spacing: Theme.Spacing.xxs) {
                    ForEach(completedGroup) { task in
                        taskRow(task)
                    }
                }
                .padding(Theme.Spacing.cardInset)
                .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        Button {
            editingTask = task
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: task.state == .completed ? "checkmark.circle.fill" : "circle")
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(task.state == .completed ? Theme.accent : Theme.textSecondary.opacity(0.7))

                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text(task.title)
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)

                    Text(task.priority.displayLabel)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                if task.state != .completed {
                    Text(assignmentDay(for: task).formatted(.dateTime.month(.abbreviated).day()))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface.opacity(0.75))
            )
        }
        .buttonStyle(.plain)
    }

    private func assignmentDay(for task: TaskItem) -> Date {
        if let assignedDate = task.assignedDate {
            return calendar.startOfDay(for: assignedDate)
        }
        return calendar.startOfDay(for: task.createdAt)
    }
}
