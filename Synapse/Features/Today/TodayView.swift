import SwiftUI
import SwiftData

struct TodayView: View {
    let taskNamespace: Namespace.ID
    @Binding var externalCaptureRequestID: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(
        filter: #Predicate<TaskItem> { $0.stateRaw == "today" },
        sort: [SortDescriptor(\TaskItem.createdAt, order: .forward)]
    )
    private var todayTasks: [TaskItem]

    @Query(
        filter: #Predicate<TaskItem> { $0.stateRaw == "completed" },
        sort: [SortDescriptor(\TaskItem.completedAt, order: .reverse)]
    )
    private var completedTasks: [TaskItem]

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .forward)])
    private var habits: [Habit]

    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .reverse)])
    private var sessions: [FocusSession]

    @State private var showingCapture = false
    @State private var isFocusMode = false
    @State private var showLaterTasks = false
    @State private var focusTimeFilter: FocusTimeFilter = .all
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var showingMonthMap = false

    @State private var focusIsRunning = false
    @State private var focusElapsedSeconds = 0
    @State private var focusTimer: Timer?
    @State private var focusTaskSeconds: [UUID: Int] = [:]
    @State private var focusActiveTaskID: UUID?

    @State private var focusToastMessage = ""
    @State private var showingFocusToast = false
    @State private var focusToastWorkItem: DispatchWorkItem?

    private enum FocusTimeFilter: String, CaseIterable {
        case all
        case morning
        case afternoon
        case evening

        var label: String {
            switch self {
            case .all: return "All"
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            }
        }
    }

    private let todayCap = 5
    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var selectedDayStart: Date { calendar.startOfDay(for: selectedDate) }
    private var selectedDayLabel: String {
        calendar.isDateInToday(selectedDayStart)
            ? "Today"
            : selectedDayStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDayStart) else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }
    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDayStart)) ?? selectedDayStart
    }
    private var monthGridDays: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(date)
            }
        }

        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private var assignedTasksForSelectedDay: [TaskItem] {
        sortedByPriority(
            todayTasks.filter { task in
                calendar.isDate(assignmentDay(for: task), inSameDayAs: selectedDayStart)
            }
        )
    }

    private var filteredTasksForSelectedDay: [TaskItem] {
        assignedTasksForSelectedDay.filter(matchesFocusTimeFilter)
    }

    private var highPriorityTasks: [TaskItem] {
        filteredTasksForSelectedDay.filter { $0.priority == .high }
    }

    private var lowAndMediumTasks: [TaskItem] {
        filteredTasksForSelectedDay.filter { $0.priority != .high }
    }

    private var visibleFocusTasks: [TaskItem] {
        guard !isFocusMode else { return highPriorityTasks }
        guard filteredTasksForSelectedDay.count > 5 else { return filteredTasksForSelectedDay }

        let visibleLowAndMediumCount = showLaterTasks
            ? lowAndMediumTasks.count
            : min(lowAndMediumTasks.count, max(0, 5 - highPriorityTasks.count))

        return highPriorityTasks + Array(lowAndMediumTasks.prefix(visibleLowAndMediumCount))
    }

    private var hiddenLaterCount: Int {
        guard !isFocusMode, filteredTasksForSelectedDay.count > 5 else { return 0 }
        let shownLowAndMedium = showLaterTasks
            ? lowAndMediumTasks.count
            : min(lowAndMediumTasks.count, max(0, 5 - highPriorityTasks.count))
        return max(0, lowAndMediumTasks.count - shownLowAndMedium)
    }

    private var carriedForwardTasks: [TaskItem] {
        assignedTasksForSelectedDay.filter { $0.carriedOverFrom != nil }
    }

    private var carriedForwardLine: String? {
        guard !carriedForwardTasks.isEmpty else { return nil }
        let hasYesterdayCarry = carriedForwardTasks.contains { task in
            guard let source = task.carriedOverFrom else { return false }
            return calendar.isDateInYesterday(source)
        }
        return hasYesterdayCarry ? "Carried forward from yesterday" : "Carried forward"
    }

    private var completedSelectedDayCount: Int {
        completedTasks.filter { task in
            calendar.isDate(assignmentDay(for: task), inSameDayAs: selectedDayStart)
        }.count
    }

    private var completionPercent: Int {
        guard todayCap > 0 else { return 0 }
        let raw = (Double(completedSelectedDayCount) / Double(todayCap)) * 100
        return max(0, min(100, Int(raw.rounded())))
    }

    private var momentumDelta: Int {
        weeklyCompletedCount(offsetWeeks: 0) - weeklyCompletedCount(offsetWeeks: -1)
    }

    private var momentumLine: String {
        if momentumDelta > 0 {
            return "Momentum ↑ +\(momentumDelta) this week"
        }
        if momentumDelta < 0 {
            return "Momentum ↓ \(momentumDelta) this week"
        }
        return "Momentum → 0 this week"
    }

    private var totalFocusSecondsSelectedDay: Int {
        let end = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) ?? .distantFuture
        let logged = sessions
            .filter { $0.startedAt >= selectedDayStart && $0.startedAt < end }
            .reduce(0) { $0 + $1.durationSeconds }
        return logged + (calendar.isDateInToday(selectedDayStart) ? focusElapsedSeconds : 0)
    }

    private var currentPartOfDay: TaskPartOfDay {
        let hour = calendar.component(.hour, from: .now)
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            header
                            calendarRail

                            if isFocusMode {
                                focusTimerStrip
                            }

                            ritualsSection

                            focusSection

                            Spacer(minLength: 88)
                        }
                        .padding(Theme.Spacing.md)
                    }

                    floatingFocusButton

                    if showingFocusToast {
                        focusToast
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, 90)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Today")
            .toolbarColorScheme(.light, for: .navigationBar)
            .sheet(isPresented: $showingCapture) {
                QuickCaptureSheet(
                    placeholder: "Capture something…",
                    canAssignDefaultDay: assignedTasksForSelectedDay.count < todayCap,
                    defaultAssignmentDay: selectedDayStart,
                    onAdded: { task, addedToToday in
                        handleCapturedTask(task, addedToToday: addedToToday)
                    }
                )
            }
            .onAppear {
                rollForwardUnfinishedTasksIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                rollForwardUnfinishedTasksIfNeeded()
            }
            .onChange(of: externalCaptureRequestID) { _, _ in
                showingCapture = true
            }
            .onChange(of: isFocusMode) { _, isEnabled in
                if isEnabled, focusActiveTaskID == nil {
                    focusActiveTaskID = highPriorityTasks.first?.id
                }
            }
            .onChange(of: selectedDayStart) { _, _ in
                showLaterTasks = false
                if let current = focusActiveTaskID,
                   !assignedTasksForSelectedDay.contains(where: { $0.id == current }) {
                    focusActiveTaskID = highPriorityTasks.first?.id
                }
            }
            .onDisappear {
                focusTimer?.invalidate()
                focusTimer = nil
            }
            .animation(.snappy(duration: 0.18), value: showingFocusToast)
            .animation(.snappy(duration: 0.2), value: isFocusMode)
            .animation(.snappy(duration: 0.18), value: showLaterTasks)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(Theme.Typography.titleLarge)
                    .foregroundStyle(Theme.text)

                Spacer(minLength: 0)

                Button {
                    let haptic = UIImpactFeedbackGenerator(style: .soft)
                    haptic.impactOccurred()
                    toggleFocusMode()
                } label: {
                    Label(isFocusMode ? "Exit Focus" : "Focus", systemImage: isFocusMode ? "pause.circle.fill" : "timer.circle")
                        .font(Theme.Typography.bodySmallStrong)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(isFocusMode ? Theme.accent2 : Theme.accent)
                }
                .buttonStyle(.plain)
            }

            Text("\(completionPercent)%")
                .font(Theme.Typography.tileValue)
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())

            Text("\(completedSelectedDayCount) of \(todayCap) complete")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText())

            Text(momentumLine)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(momentumDelta >= 0 ? Theme.success : Theme.accent2)
                .contentTransition(.numericText())

            Text("Consistency builds clarity.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary.opacity(0.86))
        }
        .padding(Theme.Spacing.cardInset)
        .background(
            headerBackground,
            in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
        )
    }

    private var calendarRail: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(selectedDayLabel)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        showingMonthMap.toggle()
                    }
                } label: {
                    Image(systemName: showingMonthMap ? "calendar.circle.fill" : "calendar.circle")
                        .font(Theme.Typography.iconCard)
                        .foregroundStyle(Theme.textSecondary.opacity(0.9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showingMonthMap ? "Collapse month" : "Expand month")
            }

            weekStrip

            if showingMonthMap {
                monthHeatmap
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.24), value: showingMonthMap)
        .contentShape(Rectangle())
        .simultaneousGesture(monthToggleGesture)
    }

    private var weekStrip: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(weekDays, id: \.self) { day in
                weekDayTile(for: day)
            }
        }
    }

    private func weekDayTile(for day: Date) -> some View {
        let summary = daySummary(for: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDayStart)
        let total = summary.pendingCount + summary.completedCount
        let progress = total > 0 ? CGFloat(summary.completedCount) / CGFloat(total) : 0
        let isComplete = total > 0 && summary.pendingCount == 0

        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                selectedDate = calendar.startOfDay(for: day)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: Theme.Spacing.xxxs) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)

                    Text(day.formatted(.dateTime.day()))
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(total == 0 ? Theme.surface.opacity(0.55) : Theme.accent.opacity(0.06 + (0.14 * progress)))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(isSelected ? Theme.accent.opacity(0.7) : Color.clear, lineWidth: 1)
                }

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.success)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var monthHeatmap: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xxs), count: 7), spacing: Theme.Spacing.xxs) {
                ForEach(Array(monthGridDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        monthCell(for: day)
                    } else {
                        Color.clear
                            .frame(height: 24)
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.xxs)
    }

    private func monthCell(for day: Date) -> some View {
        let summary = daySummary(for: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDayStart)
        let total = summary.pendingCount + summary.completedCount
        let ratio = total > 0 ? CGFloat(summary.completedCount) / CGFloat(total) : 0
        let isComplete = total > 0 && summary.pendingCount == 0

        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                selectedDate = calendar.startOfDay(for: day)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(total == 0 ? Theme.surface2.opacity(0.62) : Theme.accent.opacity(0.10 + (0.42 * ratio)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(isSelected ? Theme.accent.opacity(0.72) : .clear, lineWidth: 1)
                    }

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.success)
                        .padding(3)
                }
            }
            .frame(height: 24)
        }
        .buttonStyle(.plain)
    }

    private var headerBackground: some ShapeStyle {
        if completedSelectedDayCount >= todayCap {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Theme.surface,
                        Theme.accent.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Theme.surface)
    }

    private var ritualsSection: some View {
        Group {
            if isFocusMode {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "leaf")
                        .font(Theme.Typography.iconSmall)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Rituals hidden in Focus mode")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, Theme.Spacing.xs)
            } else {
                HabitBlock()
            }
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(icon: "scope", title: "Focus")

                Spacer(minLength: 0)

                Text(formatMinutes(totalFocusSecondsSelectedDay))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
            }

            if let carriedForwardLine, !isFocusMode {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "arrow.trianglehead.clockwise")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    Text(carriedForwardLine)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: "sun.max")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.85))
                Text("Now: \(partOfDayLabel(currentPartOfDay))")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(FocusTimeFilter.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.snappy(duration: 0.16)) {
                                focusTimeFilter = option
                                showLaterTasks = false
                            }
                        } label: {
                            Text(option.label)
                                .font(Theme.Typography.caption.weight(.semibold))
                                .foregroundStyle(focusTimeFilter == option ? Theme.accent : Theme.textSecondary)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.xxs)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(focusTimeFilter == option ? Theme.accent.opacity(0.14) : Theme.surface2)
                                )
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(
                                            focusTimeFilter == option ? Theme.accent.opacity(0.45) : Theme.textSecondary.opacity(0.16),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            if highPriorityTasks.count > 5 {
                Text("Consider limiting High priority to 3–5 tasks.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if visibleFocusTasks.isEmpty {
                EmptyStatePanel(
                    symbol: isFocusMode ? "timer" : "checklist",
                    title: isFocusMode ? "No high-priority tasks" : "No focus tasks yet",
                    subtitle: isFocusMode ? "Mark one task as High to enter focus flow." : "Assign from Inbox or capture a task."
                )
            } else {
                VStack(spacing: Theme.Spacing.xxs) {
                    ForEach(visibleFocusTasks) { task in
                        FocusTaskRow(
                            task: task,
                            namespace: taskNamespace,
                            isActive: isFocusMode && focusActiveTaskID == task.id,
                            onSelect: {
                                withAnimation(.snappy(duration: 0.16)) {
                                    focusActiveTaskID = task.id
                                }
                            },
                            onComplete: { complete(task) },
                            onSetPriority: { priority in
                                withAnimation(.snappy(duration: 0.16)) {
                                    task.priority = priority
                                }
                                try? modelContext.save()
                            }
                        )
                    }
                }
            }

            if hiddenLaterCount > 0 {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        showLaterTasks.toggle()
                    }
                } label: {
                    Text(showLaterTasks ? "Show less" : "Show \(hiddenLaterCount) more")
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.xxxs)
            }
        }
    }

    private var focusTimerStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Focus Mode")
                    .font(Theme.Typography.sectionLabel)
                    .tracking(Theme.Typography.sectionTracking)
                    .foregroundStyle(Theme.textSecondary)

                Spacer(minLength: 0)

                Text(timeString(focusElapsedSeconds))
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            if let active = activeFocusTask {
                Text(active.title)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            } else {
                Text("Select a high-priority task")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    focusIsRunning ? pauseFocusTimer() : startFocusTimer()
                } label: {
                    Text(focusIsRunning ? "Pause" : "Start")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                Button {
                    endFocusSession()
                } label: {
                    Text("End")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.bordered)
                .disabled(focusElapsedSeconds == 0)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private var floatingFocusButton: some View {
        Button {
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
            toggleFocusMode()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "timer")
                    .font(Theme.Typography.iconCard)
                Text(isFocusMode ? "In Focus" : "Focus")
                    .font(Theme.Typography.bodySmallStrong)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isFocusMode ? Theme.accent2 : Theme.accent, in: Capsule(style: .continuous))
            .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
        }
        .buttonStyle(.plain)
        .padding(.trailing, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
    }

    private var focusToast: some View {
        Text(focusToastMessage)
            .font(Theme.Typography.bodySmallStrong)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, Theme.Spacing.cardInset)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.surface, in: Capsule(style: .continuous))
            .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
    }

    private var activeFocusTask: TaskItem? {
        guard let focusActiveTaskID else { return nil }
        return assignedTasksForSelectedDay.first { $0.id == focusActiveTaskID }
    }

    private func complete(_ task: TaskItem) {
        guard task.state == .today else { return }

        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.16)) {
            task.state = .completed
            task.completedAt = .now
        }

        if focusActiveTaskID == task.id {
            focusActiveTaskID = highPriorityTasks.first(where: { $0.id != task.id })?.id
        }

        try? modelContext.save()
    }

    private func toggleFocusMode() {
        if isFocusMode {
            if focusIsRunning {
                pauseFocusTimer()
            }
            isFocusMode = false
            return
        }

        isFocusMode = true
        if focusActiveTaskID == nil {
            focusActiveTaskID = highPriorityTasks.first?.id
        }
    }

    private func startFocusTimer() {
        guard !focusIsRunning else { return }

        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        focusIsRunning = true
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            focusElapsedSeconds += 1
            if let focusActiveTaskID {
                focusTaskSeconds[focusActiveTaskID, default: 0] += 1
            }
        }
    }

    private func pauseFocusTimer() {
        guard focusIsRunning else { return }

        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()

        focusIsRunning = false
        focusTimer?.invalidate()
        focusTimer = nil
    }

    private func endFocusSession() {
        pauseFocusTimer()
        guard focusElapsedSeconds > 0 else { return }

        let now = Date()
        for (taskID, seconds) in focusTaskSeconds where seconds > 0 {
            let session = FocusSession(taskId: taskID, startedAt: now.addingTimeInterval(TimeInterval(-seconds)))
            session.endedAt = now
            session.durationSeconds = seconds
            modelContext.insert(session)

            if let task = task(withID: taskID) {
                task.focusSeconds += seconds
            }
        }

        try? modelContext.save()

        showFocusToast(minutes: max(1, focusElapsedSeconds / 60))

        focusElapsedSeconds = 0
        focusTaskSeconds = [:]
    }

    private func showFocusToast(minutes: Int) {
        focusToastWorkItem?.cancel()
        focusToastMessage = "Logged \(minutes) min"

        withAnimation(.snappy(duration: 0.18)) {
            showingFocusToast = true
        }

        let workItem = DispatchWorkItem {
            withAnimation(.snappy(duration: 0.18)) {
                showingFocusToast = false
            }
        }
        focusToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: workItem)
    }

    private func handleCapturedTask(_ task: TaskItem, addedToToday: Bool) {
        guard addedToToday else { return }
        withAnimation(.snappy(duration: 0.16)) {
            task.assignedDate = selectedDayStart
            task.carriedOverFrom = nil
        }
        try? modelContext.save()
    }

    private func rollForwardUnfinishedTasksIfNeeded() {
        var didChange = false

        for task in todayTasks {
            let day = assignmentDay(for: task)

            if day < todayStart {
                task.carriedOverFrom = day
                task.assignedDate = todayStart
                didChange = true
                continue
            }

            if task.assignedDate == nil, calendar.isDate(day, inSameDayAs: todayStart) {
                task.assignedDate = todayStart
                didChange = true
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }

    private func task(withID id: UUID) -> TaskItem? {
        if let todayMatch = todayTasks.first(where: { $0.id == id }) {
            return todayMatch
        }
        return completedTasks.first(where: { $0.id == id })
    }

    private func weeklyCompletedCount(offsetWeeks: Int) -> Int {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDayStart) else { return 0 }
        let start = calendar.date(byAdding: .day, value: offsetWeeks * 7, to: thisWeek.start) ?? thisWeek.start
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? thisWeek.end

        return completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= start && completedAt < end
        }.count
    }

    private func daySummary(for day: Date) -> (pendingCount: Int, completedCount: Int) {
        let target = calendar.startOfDay(for: day)
        let pending = todayTasks.filter { task in
            calendar.isDate(assignmentDay(for: task), inSameDayAs: target)
        }.count
        let completed = completedTasks.filter { task in
            calendar.isDate(assignmentDay(for: task), inSameDayAs: target)
        }.count
        return (pending, completed)
    }

    private func sortedByPriority(_ items: [TaskItem]) -> [TaskItem] {
        items.sorted { lhs, rhs in
            if lhs.priority.sortRank != rhs.priority.sortRank {
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
            let lhsTimeRank = partOfDaySortRank(lhs.partOfDay)
            let rhsTimeRank = partOfDaySortRank(rhs.partOfDay)
            if lhsTimeRank != rhsTimeRank {
                return lhsTimeRank < rhsTimeRank
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func matchesFocusTimeFilter(_ task: TaskItem) -> Bool {
        switch focusTimeFilter {
        case .all:
            return true
        case .morning:
            return task.partOfDay == .morning || task.partOfDay == .anytime
        case .afternoon:
            return task.partOfDay == .afternoon || task.partOfDay == .anytime
        case .evening:
            return task.partOfDay == .evening || task.partOfDay == .anytime
        }
    }

    private func partOfDaySortRank(_ partOfDay: TaskPartOfDay) -> Int {
        if focusTimeFilter != .all {
            let filterPart = partOfDayFromFilter(focusTimeFilter)
            if partOfDay == filterPart { return 0 }
            if partOfDay == .anytime { return 1 }
            return 2
        }

        if partOfDay == currentPartOfDay { return 0 }
        if partOfDay == .anytime { return 1 }

        switch (currentPartOfDay, partOfDay) {
        case (.morning, .afternoon): return 2
        case (.morning, .evening): return 3
        case (.afternoon, .evening): return 2
        case (.afternoon, .morning): return 3
        case (.evening, .morning): return 2
        case (.evening, .afternoon): return 3
        default: return 4
        }
    }

    private func partOfDayFromFilter(_ filter: FocusTimeFilter) -> TaskPartOfDay {
        switch filter {
        case .all: return .anytime
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .evening: return .evening
        }
    }

    private func partOfDayLabel(_ partOfDay: TaskPartOfDay) -> String {
        switch partOfDay {
        case .anytime: return "Anytime"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    private func assignmentDay(for task: TaskItem) -> Date {
        if let assignedDate = task.assignedDate {
            return calendar.startOfDay(for: assignedDate)
        }
        return calendar.startOfDay(for: task.createdAt)
    }

    private func timeString(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private func formatMinutes(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return "\(hours)h \(remainder)m"
    }

    private var monthToggleGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                if value.translation.height > 28, !showingMonthMap {
                    withAnimation(.snappy(duration: 0.24)) {
                        showingMonthMap = true
                    }
                } else if value.translation.height < -28, showingMonthMap {
                    withAnimation(.snappy(duration: 0.24)) {
                        showingMonthMap = false
                    }
                }
            }
    }
}

private struct FocusTaskRow: View {
    let task: TaskItem
    let namespace: Namespace.ID
    let isActive: Bool
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onSetPriority: (TaskPriority) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(priorityTone(for: task.priority))
                .frame(width: 3, height: 34)

            Button {
                onSelect()
            } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text(task.title)
                        .font(titleFont)
                        .foregroundStyle(Theme.text)
                        .opacity(task.priority == .low ? 0.8 : 1)
                        .lineLimit(2)

                    HStack(spacing: Theme.Spacing.xxs) {
                        if task.partOfDay != .anytime {
                            Text(partOfDayLabel(task.partOfDay))
                                .font(Theme.Typography.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, Theme.Spacing.xxs)
                                .padding(.vertical, 1)
                                .background(Theme.surface2, in: Capsule(style: .continuous))
                        }

                        if task.carriedOverFrom != nil {
                            Text("Carried")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.textSecondary.opacity(0.82))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                onComplete()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(Theme.Typography.iconLarge)
                    .foregroundStyle(Theme.textSecondary.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.xxs)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(isActive ? Theme.accent.opacity(0.08) : Color.clear)
        )
        .matchedGeometryEffect(id: task.id, in: namespace)
        .contentShape(Rectangle())
        .contextMenu {
            Button("High") { onSetPriority(.high) }
            Button("Medium") { onSetPriority(.medium) }
            Button("Low") { onSetPriority(.low) }
        }
    }

    private var titleFont: Font {
        switch task.priority {
        case .high:
            return Theme.Typography.itemTitleProminent
        case .medium:
            return Theme.Typography.itemTitleCompact
        case .low:
            return Theme.Typography.itemTitleCompact
        }
    }

    private func priorityTone(for priority: TaskPriority) -> Color {
        switch priority {
        case .high:
            return Theme.accent.opacity(0.68)
        case .medium:
            return Theme.textSecondary.opacity(0.34)
        case .low:
            return Theme.textSecondary.opacity(0.18)
        }
    }

    private func partOfDayLabel(_ partOfDay: TaskPartOfDay) -> String {
        switch partOfDay {
        case .anytime: return "Anytime"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
}
