import SwiftUI
import SwiftData


struct TodayView: View {
    let taskNamespace: Namespace.ID
    @Binding var externalCaptureRequestID: Int

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "today" },
           sort: [SortDescriptor(\TaskItem.createdAt, order: .forward)])
    private var todayTasks: [TaskItem]

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "completed" },
           sort: [SortDescriptor(\TaskItem.completedAt, order: .reverse)])
    private var completedTasks: [TaskItem]

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .reverse)])
    private var sessions: [FocusSession]

    @State private var focusTask: TaskItem?
    @State private var showingCapture = false
    @State private var toastTask: TaskItem?
    @State private var showingCaptureToast = false
    @State private var toastDismissWorkItem: DispatchWorkItem?
    @State private var focusLogMessage = ""
    @State private var showingFocusLogToast = false
    @State private var focusLogDismissWorkItem: DispatchWorkItem?
    @State private var showingCompletedReview = false
    @State private var momentumTriggeredDay: Date?
    @State private var milestoneTriggeredDay: Date?
    @StateObject private var brainReactor = BrainReactionController()

    private var todayCap: Int { 5 }
    private var remainingCount: Int { todayTasks.count }
    private var isDayClear: Bool { todayTasks.isEmpty }
    private var completedTodayCount: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return completedTasks.filter { ($0.completedAt ?? .distantPast) >= start }.count
    }
    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }
    private var completedHabitsTodayCount: Int {
        activeHabits.filter(\.completedToday).count
    }
    private var todayCompleted: [TaskItem] {
        let start = Calendar.current.startOfDay(for: .now)
        return completedTasks.filter { ($0.completedAt ?? .distantPast) >= start }
    }

    private var headerDenominator: Int { todayCap }

    private var focusSecondsToday: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return sessions
            .filter { $0.startedAt >= start }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    private var headerProgress: CGFloat {
        guard headerDenominator > 0 else { return 0 }
        return min(1, CGFloat(completedTodayCount) / CGFloat(headerDenominator))
    }

    private var executionRatioPercent: Int {
        Int((headerProgress * 100).rounded())
    }
    
    private var headerMicroLine: String {
        if completedTodayCount >= todayCap {
            return "Strong finish."
        }
        if completedTodayCount >= 3 { return "On track." }
        if completedTodayCount >= 1 { return "Momentum building." }
        return "Start small."
    }
    
    private var mascotExpression: BrainMascot.Expression {
        let taskWorkload = todayTasks.count + completedTodayCount
        let habitWorkload = activeHabits.count
        let totalWorkload = max(1, taskWorkload + habitWorkload)
        let completedWorkload = completedTodayCount + completedHabitsTodayCount
        let completionRatio = Double(completedWorkload) / Double(totalWorkload)
        if completionRatio >= 0.65 { return .proud }
        if completionRatio > 0.45 { return .balanced }
        return .neutral
    }

    private enum CompletionSource {
        case task
        case habit
    }

    private struct ExecutionSnapshot {
        let completedTaskCount: Int
        let completedHabitCount: Int
        let activeHabitCount: Int
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ZStack {
                    mainContent
                        .opacity(focusTask == nil ? 1 : 0.35)
                        .blur(radius: focusTask == nil ? 0 : 6)
                        .allowsHitTesting(focusTask == nil)

                    if let task = focusTask {
                        FocusModeView(
                            task: task,
                            namespace: taskNamespace,
                            heroId: task.id,
                            onClose: { focusTask = nil },
                            onSessionLogged: { minutes in
                                showFocusLogToast(minutes: minutes)
                            }
                        )
                            .zIndex(10)
                    }

                    if showingCaptureToast || showingFocusLogToast {
                        VStack(spacing: Theme.Spacing.xs) {
                            if showingFocusLogToast {
                                focusLogToast
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            if showingCaptureToast {
                                captureToast
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.md)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .zIndex(15)
                    }
                }
            }
            .navigationTitle("Today")
            .toolbarColorScheme(.light, for: .navigationBar)
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
        .sheet(isPresented: $showingCompletedReview) {
            CompletedTodaySheet(
                tasks: todayCompleted,
                onDelete: { task in
                    deleteCompletedTask(task)
                }
            )
        }
        .animation(.snappy(duration: 0.22), value: focusTask)
        .animation(.snappy(duration: 0.18), value: showingCaptureToast)
        .animation(.snappy(duration: 0.18), value: showingFocusLogToast)
        .onChange(of: externalCaptureRequestID) { _, _ in
            if focusTask != nil {
                withAnimation(.snappy(duration: 0.18)) {
                    focusTask = nil
                }
            }
            showingCapture = true
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                HabitBlock(onCompletionStateChange: handleHabitCompletionStateChange)

                if isDayClear {
                    dayClearState
                } else {
                    remainingSection
                }

                performanceTile
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.canvas.opacity(isDayClear ? 0.35 : 0.0))
        .animation(.snappy(duration: 0.18), value: isDayClear)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text("\(executionRatioPercent)%")
                        .font(Theme.Typography.heroValue)
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())

                    Text("Execution Ratio")
                        .font(Theme.Typography.sectionLabel)
                        .tracking(Theme.Typography.sectionTracking)
                        .foregroundStyle(Theme.textSecondary)

                    Text("\(completedTodayCount) / \(headerDenominator) completions")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 0)

                BrainMascotView(
                    imageName: BrainMascot.imageName(for: mascotExpression),
                    reactor: brainReactor,
                    size: 112
                )
                .padding(.top, Theme.Spacing.xxxs)
                .animation(.snappy(duration: 0.22), value: mascotExpression)
            }

            StatusChip(text: headerMicroLine, tone: .accent, uppercased: true)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(.snappy(duration: 0.2), value: headerMicroLine)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                Image(systemName: "timer")
                    .font(Theme.Typography.iconSmall)
                    .foregroundStyle(Theme.textSecondary.opacity(0.9))
                Text("\(formatMinutes(focusSecondsToday))")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
                Text("focus")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
            }

            Capsule()
                .fill(Theme.accent.opacity(0.12))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(6, proxy.size.width * headerProgress), height: 4)
                    }
                }
                .clipShape(Capsule())
                .animation(.snappy(duration: 0.22), value: headerProgress)
        }
        .padding(.bottom, Theme.Spacing.xs)
        .animation(.snappy(duration: 0.18), value: todayTasks.count)
        .animation(.snappy(duration: 0.18), value: completedTodayCount)
        .animation(.snappy(duration: 0.18), value: focusSecondsToday)
    }

    private var dayClearState: some View {
        EmptyStatePanel(
            symbol: "checkmark.circle",
            title: "Board clear.",
            subtitle: "Capture anything that comes up.",
            playful: true,
            showSparkle: true
        )
        .transition(.opacity)
    }

    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionLabel(icon: "circle.dashed", title: "Commitments (\(remainingCount))")
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.18), value: remainingCount)

            VStack(spacing: Theme.Spacing.sm) {
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

    private var performanceTile: some View {
        Button {
            showingCompletedReview = true
        } label: {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: "checkmark.seal")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent.opacity(0.55))
                        Text("Execution Log")
                            .font(Theme.Typography.sectionLabel)
                            .tracking(Theme.Typography.sectionTracking)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Text("\(completedTodayCount) \(completedTodayCount == 1 ? "completion" : "completions")")
                        .font(Theme.Typography.tileValue)
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())

                    Text("Tap to review")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
            }
            .padding(Theme.Spacing.cardInset)
            .surfaceCard()
        }
        .buttonStyle(.plain)
    }
    
    private func complete(_ task: TaskItem) {
        guard task.state == .today else { return }
        let previousState = executionSnapshot()
        let nextState = ExecutionSnapshot(
            completedTaskCount: previousState.completedTaskCount + 1,
            completedHabitCount: previousState.completedHabitCount,
            activeHabitCount: previousState.activeHabitCount
        )

        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.18)) {
            task.state = .completed
            task.completedAt = .now
        }
        try? modelContext.save()
        triggerBrainReactions(from: previousState, to: nextState, source: .task)
    }

    private func deleteCompletedTask(_ task: TaskItem) {
        withAnimation(.snappy(duration: 0.18)) {
            modelContext.delete(task)
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
        HStack(spacing: Theme.Spacing.xs) {
            Text("Added to Inbox")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            Spacer()

            if let task = toastTask, task.state == .inbox, todayTasks.count < todayCap {
                Button("Commit") {
                    commitToToday(task)
                }
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.cardInset)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface, in: Capsule(style: .continuous))
        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
    }

    private var focusLogToast: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(focusLogMessage)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.cardInset)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.surface, in: Capsule(style: .continuous))
        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
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

    private func showFocusLogToast(minutes: Int) {
        focusLogDismissWorkItem?.cancel()
        focusLogMessage = "Logged \(minutes) min"

        withAnimation(.snappy(duration: 0.18)) {
            showingFocusLogToast = true
        }

        let workItem = DispatchWorkItem {
            withAnimation(.snappy(duration: 0.18)) {
                showingFocusLogToast = false
            }
        }
        focusLogDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func handleHabitCompletionStateChange(_ snapshot: HabitCompletionSnapshot) {
        guard snapshot.didComplete else { return }
        let previousState = ExecutionSnapshot(
            completedTaskCount: completedTodayCount,
            completedHabitCount: snapshot.completedBefore,
            activeHabitCount: snapshot.activeCount
        )
        let nextState = ExecutionSnapshot(
            completedTaskCount: completedTodayCount,
            completedHabitCount: snapshot.completedAfter,
            activeHabitCount: snapshot.activeCount
        )
        triggerBrainReactions(from: previousState, to: nextState, source: .habit)
    }

    private func executionSnapshot() -> ExecutionSnapshot {
        ExecutionSnapshot(
            completedTaskCount: completedTodayCount,
            completedHabitCount: completedHabitsTodayCount,
            activeHabitCount: activeHabits.count
        )
    }

    private func triggerBrainReactions(
        from previous: ExecutionSnapshot,
        to current: ExecutionSnapshot,
        source: CompletionSource
    ) {
        let todayStart = Calendar.current.startOfDay(for: .now)
        if let trackedMomentumDay = momentumTriggeredDay,
           !Calendar.current.isDate(trackedMomentumDay, inSameDayAs: todayStart) {
            momentumTriggeredDay = nil
        }
        if let trackedMilestoneDay = milestoneTriggeredDay,
           !Calendar.current.isDate(trackedMilestoneDay, inSameDayAs: todayStart) {
            milestoneTriggeredDay = nil
        }

        switch source {
        case .task:
            brainReactor.trigger(.micro)
        case .habit:
            brainReactor.trigger(.micro)
        }

        let crossedAllRituals = previous.activeHabitCount > 0 &&
            previous.completedHabitCount < previous.activeHabitCount &&
            current.completedHabitCount >= current.activeHabitCount
        if crossedAllRituals && momentumTriggeredDay == nil {
            momentumTriggeredDay = todayStart
            brainReactor.trigger(.momentum)
        }

        let reachedCap = previous.completedTaskCount < todayCap && current.completedTaskCount >= todayCap
        if reachedCap && milestoneTriggeredDay == nil {
            milestoneTriggeredDay = todayStart
            brainReactor.trigger(.milestone)
        }
    }
}

private struct CompletedTodaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let tasks: [TaskItem]
    let onDelete: (TaskItem) -> Void
    private let calendar = Calendar.current

    private enum TimeBlock: Int, CaseIterable {
        case morning
        case afternoon
        case evening

        var title: String {
            switch self {
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            }
        }

        static func from(date: Date, calendar: Calendar) -> TimeBlock {
            let hour = calendar.component(.hour, from: date)
            if hour < 12 { return .morning }
            if hour < 17 { return .afternoon }
            return .evening
        }
    }

    private var groupedTasks: [(block: TimeBlock, items: [TaskItem])] {
        let groups = Dictionary(grouping: tasks) { task in
            let completedAt = task.completedAt ?? .now
            return TimeBlock.from(date: completedAt, calendar: calendar)
        }

        return TimeBlock.allCases.compactMap { block in
            guard var items = groups[block], !items.isEmpty else { return nil }
            items.sort { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
            return (block, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Nothing completed yet today.")
                            .font(Theme.Typography.bodyMedium.weight(.semibold))
                            .foregroundStyle(Theme.text)
                        Text("Complete one commitment to start momentum.")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(Theme.Spacing.md)
                } else {
                    List {
                        ForEach(groupedTasks, id: \.block) { group in
                            Section {
                                ForEach(group.items) { task in
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(Theme.Typography.iconCard)
                                            .foregroundStyle(Theme.accent)

                                        Text(task.title)
                                            .font(Theme.Typography.itemTitle)
                                            .foregroundStyle(Theme.text)

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 2)
                                    .listRowBackground(Theme.surface)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            onDelete(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(group.block.title)
                                    .font(Theme.Typography.sectionLabel)
                                    .tracking(Theme.Typography.sectionTracking)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .background(Theme.canvas)
            .navigationTitle("Execution Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(Theme.accent)
                }
            }
        }
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

private struct SwipeCompleteRow<Content: View>: View {
    let onComplete: () -> Void
    let onTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var settledOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @GestureState private var isDraggingHorizontally = false
    @State private var isCompleting = false
    @State private var suppressTapUntil = Date.distantPast

    private let revealThreshold: CGFloat = -48
    private let revealOffset: CGFloat = -76
    private let triggerThreshold: CGFloat = -124
    private let maxSwipe: CGFloat = -170

    private var activeOffset: CGFloat {
        clampedOffset(settledOffset + dragOffset)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.success.opacity(0.18))
                .overlay(alignment: .trailing) {
                    HStack(spacing: Theme.Spacing.compact) {
                        Image(systemName: "checkmark")
                        Text("Complete")
                            .font(Theme.Typography.labelSmallStrong)
                    }
                    .foregroundStyle(Theme.success)
                    .padding(.trailing, Theme.Spacing.md)
                    .opacity(min(1, abs(activeOffset) / abs(revealOffset)))
                }

            content()
                .offset(x: activeOffset)
                .allowsHitTesting(!isDraggingHorizontally && !isCompleting && settledOffset == 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDraggingHorizontally, !isCompleting else { return }
            guard Date() >= suppressTapUntil else { return }

            if settledOffset != 0 {
                withAnimation(.snappy(duration: 0.18)) {
                    settledOffset = 0
                }
                return
            }
            onTap?()
        }
        .simultaneousGesture(dragGesture)
        .animation(.snappy(duration: 0.18), value: settledOffset)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($isDraggingHorizontally) { value, state, _ in
                state = abs(value.translation.width) > abs(value.translation.height)
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
                suppressTapUntil = .now.addingTimeInterval(0.18)

                let finalOffset = clampedOffset(settledOffset + value.translation.width)
                if finalOffset <= triggerThreshold {
                    triggerComplete()
                } else if finalOffset <= revealThreshold {
                    settledOffset = revealOffset
                } else {
                    settledOffset = 0
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
