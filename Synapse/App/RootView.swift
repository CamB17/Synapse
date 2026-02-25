import SwiftUI
import UIKit
import SwiftData

struct RootView: View {
    @Namespace private var taskNamespace
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .today
    @State private var captureRequestID = 0
    @State private var hideTabBar = false
    @State private var showingUniversalCapture = false
    @State private var showingTaskCapture = false
    @State private var showingAppointmentCapture = false
    @State private var showingHabitCapture = false

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "today" })
    private var todayTasks: [TaskItem]
    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "inbox" })
    private var legacyInboxTasks: [TaskItem]
    @Query(sort: [SortDescriptor(\Habit.sortOrder, order: .reverse)])
    private var habits: [Habit]

    private let todayCap = 5
    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var canAssignToday: Bool {
        todayTasks.filter { task in
            guard let assignedDate = task.assignedDate else { return false }
            return calendar.isDate(assignedDate, inSameDayAs: todayStart)
        }.count < todayCap
    }

    private enum Tab: Hashable {
        case today
        case habits
        case review
    }

    var body: some View {
        ZStack {
            TodayView(
                taskNamespace: taskNamespace,
                externalCaptureRequestID: $captureRequestID,
                hideBottomNavigation: $hideTabBar
            )
            .opacity(selectedTab == .today ? 1 : 0)
            .allowsHitTesting(selectedTab == .today)

            ManageHabitsView(title: "Habits", showsDoneButton: false)
                .opacity(selectedTab == .habits ? 1 : 0)
                .allowsHitTesting(selectedTab == .habits)

            ReviewView()
                .opacity(selectedTab == .review ? 1 : 0)
                .allowsHitTesting(selectedTab == .review)
        }
        .animation(Motion.easing, value: selectedTab)
        .animation(Motion.easing, value: hideTabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !hideTabBar {
                customTabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingUniversalCapture) {
            UniversalCaptureSheet(
                onAddTask: {
                    withAnimation(Motion.easing) {
                        selectedTab = .today
                    }
                    showingTaskCapture = true
                },
                onAddAppointment: {
                    withAnimation(Motion.easing) {
                        selectedTab = .today
                    }
                    showingAppointmentCapture = true
                },
                onAddHabit: {
                    withAnimation(Motion.easing) {
                        selectedTab = .habits
                    }
                    showingHabitCapture = true
                },
                onStartFocus: nil
            )
            .presentationDetents([.height(universalCaptureDetentHeight)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTaskCapture) {
            QuickCaptureSheet(
                placeholder: "Task title",
                canAssignDefaultDay: canAssignToday,
                defaultAssignmentDay: todayStart,
                onAdded: { _, _ in }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAppointmentCapture) {
            AppointmentEditorSheet(defaultStartDate: .now)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingHabitCapture) {
            HabitEditorSheet(
                defaultSortOrder: nextHabitSortOrder
            )
        }
        .onAppear {
            migrateLegacyInboxTasksIfNeeded()
        }
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                tabButton(tab: .today, title: "Today", icon: "checklist")

                addCaptureButton

                tabButton(tab: .habits, title: "Habits", icon: "leaf")
                tabButton(tab: .review, title: "Review", icon: "chart.bar")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.compact)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .shadow(color: Theme.cardShadow().opacity(0.45), radius: 12, y: -3)
    }

    private func tabButton(tab: Tab, title: String, icon: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(Motion.easing) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: Theme.Spacing.xxxs) {
                Image(systemName: icon)
                    .font(Theme.Typography.iconCard)
                Text(title)
                    .font(Theme.Typography.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var addCaptureButton: some View {
        Button {
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
            showingUniversalCapture = true
        } label: {
            Image(systemName: "plus")
                .font(Theme.Typography.iconMedium)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.accent, in: Circle())
                .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture")
        .frame(maxWidth: .infinity)
    }

    private var nextHabitSortOrder: Int {
        (habits.map(\.sortOrder).max() ?? -1) + 1
    }

    private var universalCaptureDetentHeight: CGFloat {
        332
    }

    private func migrateLegacyInboxTasksIfNeeded() {
        guard !legacyInboxTasks.isEmpty else { return }

        for task in legacyInboxTasks {
            task.state = .today
            if task.assignedDate == nil {
                task.assignedDate = todayStart
            }
            task.carriedOverFrom = nil
        }

        do {
            try modelContext.save()
        } catch {
            print("Legacy inbox migration error: \(error)")
        }
    }
}
