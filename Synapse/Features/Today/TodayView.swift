import SwiftUI
import SwiftData


struct TodayView: View {
    let taskNamespace: Namespace.ID

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
    @State private var focusLogMessage = ""
    @State private var showingFocusLogToast = false
    @State private var focusLogDismissWorkItem: DispatchWorkItem?
    @State private var pulsing = false
    @State private var showingCompletedReview = false

    private var todayCap: Int { 5 }
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
    
    private var headerProgress: CGFloat {
        guard headerDenominator > 0 else { return 0 }
        return min(1, CGFloat(completedTodayCount) / CGFloat(headerDenominator))
    }
    
    private var headerMicroLine: String {
        if completedTodayCount >= todayCap {
            return "Strong finish."
        }
        if completedTodayCount >= 3 { return "On track." }
        if completedTodayCount >= 1 { return "Momentum building." }
        return "Start small."
    }
    
    private var dailyInsightLine: String {
        if completedTodayCount >= todayCap {
            return "Clean execution today."
        }
        if focusSecondsToday >= 60 * 60 {
            return "You protected your focus."
        }
        if completedTodayCount >= 3 {
            return "Consistency compounds."
        }
        if completedTodayCount > 0 {
            return "Small wins stack."
        }
        return "Start small, stay steady."
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
                        VStack(spacing: 8) {
                            if showingFocusLogToast {
                                focusLogToast
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            if showingCaptureToast {
                                captureToast
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .zIndex(15)
                    }
                }
            }
            .navigationTitle("Today")
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCapture = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.accent)
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
        .sheet(isPresented: $showingCompletedReview) {
            CompletedTodaySheet(tasks: todayCompleted)
        }
        .animation(.snappy(duration: 0.22), value: focusTask)
        .animation(.snappy(duration: 0.18), value: showingCaptureToast)
        .animation(.snappy(duration: 0.18), value: showingFocusLogToast)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                HabitBlock()

                if isDayClear {
                    dayClearState
                } else {
                    remainingSection
                }
                
                performanceTile
                dailyInsightTile
            }
            .padding(16)
        }
        .background(Theme.canvas.opacity(isDayClear ? 0.35 : 0.0))
        .animation(.snappy(duration: 0.18), value: isDayClear)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(completedTodayCount)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())

                Text("/ \(headerDenominator)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Text(headerMicroLine.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(Theme.accent.opacity(0.9))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.accent.opacity(0.1))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.accent.opacity(0.16), lineWidth: 0.5)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(.snappy(duration: 0.2), value: headerMicroLine)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(formatMinutes(focusSecondsToday))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())

                Text("focused")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Capsule()
                .fill(Theme.accent.opacity(0.12))
                .frame(height: 7)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(8, proxy.size.width * headerProgress), height: 7)
                    }
                }
                .clipShape(Capsule())
                .animation(.snappy(duration: 0.22), value: headerProgress)

            Divider().padding(.top, 6)
        }
        .scaleEffect(pulsing ? 1.01 : 1.0)
        .animation(.snappy(duration: 0.18), value: pulsing)
        .animation(.snappy(duration: 0.18), value: todayTasks.count)
        .animation(.snappy(duration: 0.18), value: completedTodayCount)
        .animation(.snappy(duration: 0.18), value: focusSecondsToday)
    }

    private var dayClearState: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Illustration(symbol: "checkmark.circle", style: .playful, size: 34)
                SparkleOverlay()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Board clear.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)

                Text("Capture anything that comes up.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        )
        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
        .transition(.opacity)
    }

    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.accent.opacity(0.45))

                Text("Commitments (\(remainingCount))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(0.3)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.18), value: remainingCount)
            }

            VStack(spacing: 8) {
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
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completed Today")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .tracking(0.6)

                    Text("\(completedTodayCount) \(completedTodayCount == 1 ? "action" : "actions")")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())

                    Text("Tap to review")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
            }
            .padding(14)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
            )
            .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
        }
        .buttonStyle(.plain)
    }
    
    private var dailyInsightTile: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent.opacity(0.5))
            Text(dailyInsightLine)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func complete(_ task: TaskItem) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.18)) {
            task.state = .completed
            task.completedAt = .now
        }
        try? modelContext.save()
        pulseHeader()
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
                .foregroundStyle(Theme.text)

            Spacer()

            if let task = toastTask, task.state == .inbox, todayTasks.count < todayCap {
                Button("Commit") {
                    commitToToday(task)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface, in: Capsule(style: .continuous))
        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
    }

    private var focusLogToast: some View {
        HStack(spacing: 10) {
            Text(focusLogMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
        pulseHeader()

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

    private func pulseHeader() {
        withAnimation(.snappy(duration: 0.2)) {
            pulsing = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.snappy(duration: 0.18)) {
                pulsing = false
            }
        }
    }
}

private struct CompletedTodaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let tasks: [TaskItem]

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nothing completed yet today.")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text)
                        Text("Complete one commitment to start momentum.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
                } else {
                    List {
                        ForEach(tasks) { task in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.accent)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.text)
                                    if let completedAt = task.completedAt {
                                        Text(timeFormatter.string(from: completedAt))
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 2)
                            .listRowBackground(Theme.surface)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .background(Theme.canvas)
            .navigationTitle("Completed Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(Theme.accent)
                }
            }
        }
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
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
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Complete")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.success)
                    .padding(.trailing, 16)
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
