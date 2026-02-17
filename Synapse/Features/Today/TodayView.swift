import SwiftUI
import SwiftData


struct TodayView: View {
    @Namespace private var taskNamespace

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "today" },
           sort: [SortDescriptor(\TaskItem.createdAt, order: .forward)])
    private var todayTasks: [TaskItem]

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "completed" },
           sort: [SortDescriptor(\TaskItem.completedAt, order: .reverse)])
    private var completedTasks: [TaskItem]

    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .reverse)])
    private var sessions: [FocusSession]

    @State private var focusTask: TaskItem?
    @State private var showingCapture = false
    @State private var toastTask: TaskItem?
    @State private var showingCaptureToast = false
    @State private var toastDismissWorkItem: DispatchWorkItem?

    private var todayCap: Int { 5 }
    private var plannedCount: Int { min(todayTasks.count + remainingSlack, todayCap) } // for header clarity
    private var remainingCount: Int { todayTasks.count }
    private var isDayClear: Bool { todayTasks.isEmpty }
    private var completedTodayCount: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return completedTasks.filter { ($0.completedAt ?? .distantPast) >= start }.count
    }
    private var todayCompleted: [TaskItem] {
        let start = Calendar.current.startOfDay(for: .now)
        return completedTasks.filter { ($0.completedAt ?? .distantPast) >= start }
    }

    // If you want header to be “X / 5 Cleared” regardless of how many you planned, keep it fixed at 5.
    private var headerDenominator: Int { todayCap }

    private var focusSecondsToday: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return sessions
            .filter { $0.startedAt >= start }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    // This keeps header stable even if user has fewer than 5 tasks.
    private var remainingSlack: Int {
        max(0, todayCap - todayTasks.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent

                if let task = focusTask {
                    FocusModeView(task: task, onClose: { focusTask = nil })
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .zIndex(10)
                }

                if showingCaptureToast {
                    captureToast
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(15)
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCapture = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .accessibilityLabel("Capture task")
                }
            }
        }
        .sheet(isPresented: $showingCapture) {
            QuickCaptureSheet(
                placeholder: "Capture something…",
                canAddToToday: todayTasks.count < todayCap,
                onAdded: { task, addedToToday in
                    handleCapturedTask(task, addedToToday: addedToToday)
                }
            )
        }
        .animation(.snappy(duration: 0.22), value: focusTask)
        .animation(.snappy(duration: 0.18), value: showingCaptureToast)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isDayClear {
                    dayClearState
                } else {
                    remainingSection
                }

                completedSection
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Completion: show completed vs cap (or vs planned if you prefer)
            HStack(alignment: .firstTextBaseline) {
                Text("\(completedTodayCount)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())

                Text("/ \(headerDenominator) Cleared")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .animation(.snappy(duration: 0.18), value: completedTodayCount)

            Text("\(formatMinutes(focusSecondsToday)) focused today")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Divider().padding(.top, 6)
        }
    }

    private var dayClearState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Day complete.")
                .font(.system(size: 18, weight: .semibold))

            Text("Your board is clear. Capture anything new as it comes up.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.opacity)
    }

    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REMAINING (\(remainingCount))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            VStack(spacing: 10) {
                ForEach(todayTasks) { task in
                    SwipeCompleteRow(
                        onComplete: { complete(task) },
                        onTap: { focusTask = task }
                    ) {
                        TaskCard(
                            id: task.id,
                            namespace: taskNamespace,
                            title: task.title,
                            subtitle: "Tap to focus",
                            prominent: true,
                            isCompleted: false,
                            onTap: nil,
                            onComplete: { complete(task) }
                        )
                    }
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPLETED")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                if todayCompleted.isEmpty {
                    Text("Nothing completed yet today.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(todayCompleted) { task in
                        TaskCard(
                            id: task.id,
                            namespace: taskNamespace,
                            title: task.title,
                            subtitle: "Done",
                            prominent: false,
                            isCompleted: true,
                            onTap: nil,
                            onComplete: nil
                        )
                        .opacity(0.85)
                        .animation(.snappy(duration: 0.18), value: todayCompleted.count)
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    private func complete(_ task: TaskItem) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.18)) {
            task.state = .completed
            task.completedAt = .now
        }
        try? modelContext.save()
    }

    private func formatMinutes(_ seconds: Int) -> String {
        let mins = max(0, seconds) / 60
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        return "\(h)h \(m)m"
    }

    private var captureToast: some View {
        HStack(spacing: 10) {
            Text("Added to Inbox")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if let task = toastTask, task.state == .inbox, todayTasks.count < todayCap {
                Button("Commit") {
                    commitToToday(task)
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }

    private func handleCapturedTask(_ task: TaskItem, addedToToday: Bool) {
        guard !addedToToday else { return }
        toastTask = task
        showingCaptureToast = true
        scheduleToastDismiss()
    }

    private func commitToToday(_ task: TaskItem) {
        guard task.state == .inbox, todayTasks.count < todayCap else { return }
        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.18)) {
            task.state = .today
            showingCaptureToast = false
        }
        toastDismissWorkItem?.cancel()
        toastDismissWorkItem = nil
        try? modelContext.save()
    }

    private func scheduleToastDismiss() {
        toastDismissWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            withAnimation(.snappy(duration: 0.18)) {
                showingCaptureToast = false
            }
        }
        toastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: workItem)
    }
}

private struct SwipeCompleteRow<Content: View>: View {
    let onComplete: () -> Void
    let onTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var settledOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isCompleting = false
    @State private var isSwipeActive = false

    private let revealThreshold: CGFloat = -48
    private let revealOffset: CGFloat = -76
    private let triggerThreshold: CGFloat = -124
    private let maxSwipe: CGFloat = -170
    private let leadingControlWidth: CGFloat = 56

    private var activeOffset: CGFloat {
        clampedOffset(settledOffset + dragOffset)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.green.opacity(0.18))
                .overlay(alignment: .trailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Complete")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.green)
                    .padding(.trailing, 16)
                    .opacity(min(1, abs(activeOffset) / abs(revealOffset)))
                }

            content()
                .offset(x: activeOffset)
                .allowsHitTesting(!isSwipeActive && !isCompleting && settledOffset == 0)
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    guard !isSwipeActive, !isCompleting else { return }

                    // Ignore taps on the leading completion control area.
                    guard value.location.x > leadingControlWidth else { return }

                    if settledOffset != 0 {
                        withAnimation(.snappy(duration: 0.18)) {
                            settledOffset = 0
                        }
                        return
                    }
                    onTap?()
                }
        )
        .simultaneousGesture(dragGesture)
        .animation(.snappy(duration: 0.18), value: settledOffset)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if !isSwipeActive {
                    isSwipeActive = true
                }
            }
            .updating($dragOffset) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    state = 0
                    return
                }
                let proposed = settledOffset + value.translation.width
                state = clampedOffset(proposed) - settledOffset
            }
            .onEnded { value in
                guard !isCompleting else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let finalOffset = clampedOffset(settledOffset + value.translation.width)
                if finalOffset <= triggerThreshold {
                    triggerComplete()
                } else if finalOffset <= revealThreshold {
                    settledOffset = revealOffset
                } else {
                    settledOffset = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isSwipeActive = false
                }
            }
    }

    private func clampedOffset(_ value: CGFloat) -> CGFloat {
        min(0, max(maxSwipe, value))
    }

    private func triggerComplete() {
        isCompleting = true

        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        settledOffset = 0
        onComplete()
        isCompleting = false
    }
}
