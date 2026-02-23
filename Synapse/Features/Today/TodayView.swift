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
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var showingMonthMap = false
    @State private var weekSlideOffset: CGFloat = 0
    @State private var insightLineIndex = 0
    @State private var quickSummaryDay: Date?
    @State private var quickSummaryDismissWorkItem: DispatchWorkItem?
    @StateObject private var brainReactor = BrainReactionController()

    private var todayCap: Int { 5 }
    private var calendar: Calendar { .current }
    private var selectedDayStart: Date { calendar.startOfDay(for: selectedDate) }
    private var selectedDayIsToday: Bool { calendar.isDateInToday(selectedDayStart) }
    private var selectedDayTitle: String {
        selectedDayStart.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
    private var selectedDaySubtitle: String {
        selectedDayIsToday ? "Today" : selectedDayStart.formatted(date: .abbreviated, time: .omitted)
    }
    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDayStart)) ?? selectedDayStart
    }
    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let startIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        let leading = Array(symbols[startIndex...])
        let trailing = Array(symbols[..<startIndex])
        return leading + trailing
    }
    private var monthGridDays: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekdayOfMonth = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

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
    private var pendingCountsByDay: [Date: Int] {
        Dictionary(grouping: todayTasks) { calendar.startOfDay(for: $0.createdAt) }
            .mapValues(\.count)
    }
    private var completedCountsByDay: [Date: Int] {
        Dictionary(grouping: completedTasks) { calendar.startOfDay(for: $0.createdAt) }
            .mapValues(\.count)
    }
    private var streakSummary: (current: Int, best: Int) {
        let completionDays = completedCountsByDay
            .filter { $0.value > 0 }
            .keys
            .sorted()

        guard !completionDays.isEmpty else { return (0, 0) }

        var best = 1
        var run = 1

        for index in 1..<completionDays.count {
            let previous = completionDays[index - 1]
            let expected = calendar.date(byAdding: .day, value: 1, to: previous) ?? previous
            if calendar.isDate(completionDays[index], inSameDayAs: expected) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }

        let completionSet = Set(completionDays)
        var current = 0
        var cursor = selectedDayStart

        while completionSet.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            if current > 365 { break }
        }

        return (current, best)
    }
    private var plannerBridgeLine: String {
        if streakSummary.current > 0 {
            return "Today contributes to your streak • \(streakSummary.current)-day run."
        }
        return "Today contributes to your streak."
    }
    private var weeklyPerformance: (current: Int, previous: Int, delta: Int) {
        let current = weeklyCompletionPercent(offsetFromSelectedWeek: 0)
        let previous = weeklyCompletionPercent(offsetFromSelectedWeek: -1)
        return (current, previous, current - previous)
    }
    private var weeklyPerformanceDirectionSymbol: String {
        if weeklyPerformance.delta > 0 { return "arrow.up.right" }
        if weeklyPerformance.delta < 0 { return "arrow.down.right" }
        return "minus"
    }
    private var weeklyPerformanceDirectionColor: Color {
        if weeklyPerformance.delta > 0 { return Theme.success }
        if weeklyPerformance.delta < 0 { return Theme.accent2 }
        return Theme.textSecondary.opacity(0.8)
    }
    private var primaryContextualInsightLine: String {
        if completedTodayCount > 0 {
            return "\(completedTodayCount) commitment\(completedTodayCount == 1 ? "" : "s") completed."
        }
        if streakSummary.current > 0 {
            let daysToBest = max(1, (streakSummary.best + 1) - streakSummary.current)
            return "\(daysToBest) day\(daysToBest == 1 ? "" : "s") to set a new streak."
        }
        if let weekdayInsight = strongestWeekdayInsight {
            return weekdayInsight
        }
        return "Start your streak."
    }
    private var contextualInsightLines: [String] {
        var lines = [primaryContextualInsightLine]
        if let weekdayInsight = strongestWeekdayInsight {
            lines.append(weekdayInsight)
        }
        if streakSummary.current > 0 {
            let daysToBest = max(1, (streakSummary.best + 1) - streakSummary.current)
            lines.append("\(daysToBest) day\(daysToBest == 1 ? "" : "s") to set a new streak.")
        }
        if weeklyPerformance.delta != 0 {
            lines.append("This week is \(weeklyPerformance.delta > 0 ? "up" : "down") \(abs(weeklyPerformance.delta))% versus last week.")
        }

        var deduped: [String] = []
        for line in lines where !deduped.contains(line) {
            deduped.append(line)
        }
        return deduped
    }
    private var contextualInsightLine: String {
        let lines = contextualInsightLines
        guard !lines.isEmpty else { return "Start your streak." }
        let safeIndex = min(max(0, insightLineIndex), lines.count - 1)
        return lines[safeIndex]
    }
    private var strongestWeekdayInsight: String? {
        let grouped = Dictionary(grouping: completedTasks) { task in
            calendar.component(.weekday, from: task.createdAt)
        }
        let ordered = grouped
            .map { (weekday: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        guard let strongest = ordered.first, strongest.count > 1 else { return nil }
        let strongestSymbol = calendar.weekdaySymbols[max(0, min(calendar.weekdaySymbols.count - 1, strongest.weekday - 1))]
        guard let baseline = ordered.dropFirst().map(\.count).max(), baseline > 0 else {
            return "You are most consistent on \(strongestSymbol)s."
        }
        let gain = Int(((Double(strongest.count - baseline) / Double(baseline)) * 100).rounded())
        return "You complete \(max(1, gain))% more on \(strongestSymbol)s."
    }
    private var quickSummaryText: String? {
        guard let day = quickSummaryDay else { return nil }
        let summary = daySummary(for: day)
        let dayLabel = day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let pendingLabel = summary.pendingCount == 1 ? "1 pending" : "\(summary.pendingCount) pending"
        let completedLabel = summary.completedCount == 1 ? "1 completed" : "\(summary.completedCount) completed"
        return "\(dayLabel) • \(pendingLabel) • \(completedLabel)"
    }
    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDayStart) else {
            return []
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }
    private var selectedTodayTasks: [TaskItem] {
        todayTasks.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDayStart) }
    }
    private var remainingCount: Int { selectedTodayTasks.count }
    private var isDayClear: Bool { selectedTodayTasks.isEmpty }
    private var completedTodayCount: Int {
        completedCountsByDay[selectedDayStart, default: 0]
    }
    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }
    private var completedHabitsTodayCount: Int {
        activeHabits.filter(\.completedToday).count
    }
    private var todayCompleted: [TaskItem] {
        completedTasks.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDayStart) }
    }

    private var headerDenominator: Int { todayCap }

    private var focusSecondsToday: Int {
        let start = selectedDayStart
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? .distantFuture
        return sessions
            .filter { $0.startedAt >= start && $0.startedAt < end }
            .reduce(0) { $0 + $1.durationSeconds }
    }
    
    private var headerProgress: CGFloat {
        guard headerDenominator > 0 else { return 0 }
        return min(1, CGFloat(completedTodayCount) / CGFloat(headerDenominator))
    }

    private var executionRatioPercent: Int {
        Int((headerProgress * 100).rounded())
    }
    
    private var mascotExpression: BrainMascot.Expression {
        let taskWorkload = selectedTodayTasks.count + completedTodayCount
        let habitWorkload = selectedDayIsToday ? activeHabits.count : 0
        let totalWorkload = max(1, taskWorkload + habitWorkload)
        let completedWorkload = completedTodayCount + (selectedDayIsToday ? completedHabitsTodayCount : 0)
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
                canAddToToday: selectedTodayTasks.count < todayCap,
                onAdded: { task, addedToToday in
                    handleCapturedTask(task, addedToToday: addedToToday)
                }
            )
        }
        .sheet(isPresented: $showingCompletedReview) {
            CompletedTodaySheet(
                dayTitle: selectedDayTitle,
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
                calendarDeck
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

    private var calendarDeck: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                    Text("This week: \(weeklyPerformance.current)%")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.text)

                    Image(systemName: weeklyPerformanceDirectionSymbol)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(weeklyPerformanceDirectionColor)

                    Text("\(weeklyPerformance.delta >= 0 ? "+" : "")\(weeklyPerformance.delta)% vs last week")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                }

                Capsule()
                    .fill(Theme.surface2)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Theme.accent)
                                .frame(width: max(4, proxy.size.width * (CGFloat(weeklyPerformance.current) / 100)), height: 3)
                        }
                    }
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Theme.Spacing.xxs)

            Text(plannerBridgeLine)
                .font(Theme.Typography.caption)
                .foregroundStyle(streakSummary.current > 0 ? Theme.success : Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.xxs)

            HStack(spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.compact) {
                    Image(systemName: "calendar")
                        .font(Theme.Typography.iconSmall)
                        .foregroundStyle(Theme.accent)
                    Text("Planner")
                        .font(Theme.Typography.sectionLabel)
                        .tracking(Theme.Typography.sectionTracking)
                        .foregroundStyle(Theme.textSecondary)

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            showingMonthMap.toggle()
                        }
                    } label: {
                        Image(systemName: showingMonthMap ? "chevron.up" : "chevron.down")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }

            if showingMonthMap {
                monthMapCalendar
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                weekCalendar
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.snappy(duration: 0.2), value: showingMonthMap)
        .padding(Theme.Spacing.cardInset)
        .surfaceCard()
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
                    size: 88
                )
                .padding(.top, Theme.Spacing.xxxs)
                .animation(.snappy(duration: 0.22), value: mascotExpression)
            }

            Text(contextualInsightLine)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(.snappy(duration: 0.2), value: contextualInsightLine)

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
        .task(id: contextualInsightLines.count) {
            insightLineIndex = 0
            guard contextualInsightLines.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                guard !Task.isCancelled else { break }
                withAnimation(.snappy(duration: 0.22)) {
                    insightLineIndex = (insightLineIndex + 1) % max(1, contextualInsightLines.count)
                }
            }
        }
        .onChange(of: selectedDayStart) { _, _ in
            insightLineIndex = 0
        }
        .padding(.bottom, Theme.Spacing.xs)
        .animation(.snappy(duration: 0.18), value: selectedTodayTasks.count)
        .animation(.snappy(duration: 0.18), value: completedTodayCount)
        .animation(.snappy(duration: 0.18), value: focusSecondsToday)
    }

    private var dayClearState: some View {
        EmptyStatePanel(
            symbol: "checkmark.circle",
            title: completedTodayCount > 0 ? "All done for \(selectedDaySubtitle)." : "No commitments on \(selectedDaySubtitle).",
            subtitle: completedTodayCount > 0 ? "Nice work. You cleared this date." : "Capture something to plan this day.",
            playful: true,
            showSparkle: true
        )
        .transition(.opacity)
    }

    private var weekCalendar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedDayTitle)
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)

                Spacer(minLength: 0)
            }

            HStack(spacing: Theme.Spacing.xs) {
                ForEach(weekDays, id: \.self) { day in
                    weekDayCell(for: day)
                }
            }
        }
        .offset(x: weekSlideOffset)
        .animation(.snappy(duration: 0.22), value: weekSlideOffset)
        .contentShape(Rectangle())
        .simultaneousGesture(weekCalendarDragGesture)
    }

    private var monthMapCalendar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text("Month Heatmap")
                        .font(Theme.Typography.sectionLabel)
                        .tracking(Theme.Typography.sectionTracking)
                        .foregroundStyle(Theme.textSecondary)
                    Text(monthTitle)
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Button {
                    shiftSelectedMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(Theme.Typography.iconSmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)

                Button {
                    shiftSelectedMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(Theme.Typography.iconSmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
            }

            if let quickSummaryText {
                Text(quickSummaryText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.compact)
                    .background(Theme.surface2, in: Capsule(style: .continuous))
                    .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xxs), count: 7), spacing: Theme.Spacing.xxs) {
                    ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(monthGridDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            monthDayCell(for: day)
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }

                monthMapLegend
            }
            .contentShape(Rectangle())
            .simultaneousGesture(monthCalendarDragGesture)
        }
    }

    private func monthDayCell(for day: Date) -> some View {
        let summary = daySummary(for: day)
        let pendingCount = summary.pendingCount
        let completedCount = summary.completedCount
        let totalCount = pendingCount + completedCount
        let intensity = min(1, CGFloat(totalCount) / 4.0)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDayStart)
        let isToday = calendar.isDateInToday(day)
        let isComplete = totalCount > 0 && pendingCount == 0

        return Button {
            selectDay(day)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        totalCount == 0
                        ? Theme.surface2
                        : Theme.accent.opacity(0.12 + (0.42 * intensity))
                    )

                if isSelected {
                    Circle()
                        .stroke(Theme.accent, lineWidth: 1.8)
                        .padding(1)
                } else if isToday {
                    Circle()
                        .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
                        .padding(1)
                }

                VStack(spacing: 2) {
                    Text(day.formatted(.dateTime.day()))
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.text)

                    if isComplete {
                        Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.success)
                    }
                }
            }
            .frame(height: 44)
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .shadow(
                color: isSelected ? Theme.accent.opacity(0.2) : .clear,
                radius: isSelected ? 8 : 0,
                y: isSelected ? 4 : 0
            )
            .animation(.snappy(duration: 0.2), value: selectedDayStart)
        }
        .buttonStyle(PressableCalendarDayButtonStyle())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                jumpToReview(for: day)
            }
        )
        .onLongPressGesture(minimumDuration: 0.35) {
            showQuickSummary(for: day)
        }
    }

    private struct PressableCalendarDayButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.snappy(duration: 0.14), value: configuration.isPressed)
        }
    }

    private var monthMapLegend: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.success.opacity(0.9))
            Label("Selected", systemImage: "scope")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.accent.opacity(0.85))
        }
    }

    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionLabel(icon: "circle.dashed", title: "Commitments (\(remainingCount))")
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.18), value: remainingCount)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(selectedTodayTasks) { task in
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
        let dayBefore = daySummary(for: task.createdAt)
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

        if dayBefore.pendingCount == 1 {
            let completionHaptic = UINotificationFeedbackGenerator()
            completionHaptic.notificationOccurred(.success)
        }

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

    private func daySummary(for day: Date) -> (pendingCount: Int, completedCount: Int) {
        let key = calendar.startOfDay(for: day)
        let pending = pendingCountsByDay[key, default: 0]
        let completed = completedCountsByDay[key, default: 0]
        return (pending, completed)
    }

    private func weeklyCompletionPercent(offsetFromSelectedWeek offset: Int) -> Int {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDayStart) else { return 0 }
        let start = calendar.date(byAdding: .day, value: offset * 7, to: currentWeek.start) ?? currentWeek.start
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? currentWeek.end

        let pending = todayTasks.filter { $0.createdAt >= start && $0.createdAt < end }.count
        let completed = completedTasks.filter { $0.createdAt >= start && $0.createdAt < end }.count
        let total = pending + completed
        guard total > 0 else { return 0 }
        return Int((Double(completed) / Double(total) * 100).rounded())
    }

    private func selectDay(_ day: Date) {
        withAnimation(.snappy(duration: 0.18)) {
            selectedDate = calendar.startOfDay(for: day)
        }
    }

    private func shiftSelectedMonth(by monthOffset: Int) {
        guard let shiftedDate = calendar.date(byAdding: .month, value: monthOffset, to: selectedDayStart) else { return }
        let preferredDay = calendar.component(.day, from: selectedDayStart)
        let maxDayInMonth = calendar.range(of: .day, in: .month, for: shiftedDate)?.count ?? preferredDay
        var components = calendar.dateComponents([.year, .month], from: shiftedDate)
        components.day = min(preferredDay, maxDayInMonth)
        let candidate = calendar.date(from: components) ?? shiftedDate
        selectDay(candidate)
    }

    private func shiftSelectedWeek(by weekOffset: Int) {
        guard let shifted = calendar.date(byAdding: .day, value: weekOffset * 7, to: selectedDayStart) else { return }
        weekSlideOffset = weekOffset > 0 ? 18 : -18
        withAnimation(.snappy(duration: 0.22)) {
            selectedDate = calendar.startOfDay(for: shifted)
            weekSlideOffset = 0
        }
    }

    private func jumpToReview(for day: Date) {
        selectDay(day)
        DispatchQueue.main.async {
            showingCompletedReview = true
        }
    }

    private func showQuickSummary(for day: Date) {
        quickSummaryDismissWorkItem?.cancel()
        quickSummaryDay = calendar.startOfDay(for: day)

        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()

        let dismissWorkItem = DispatchWorkItem {
            withAnimation(.snappy(duration: 0.18)) {
                quickSummaryDay = nil
            }
        }
        quickSummaryDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9, execute: dismissWorkItem)
    }

    private var weekCalendarDragGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width <= -42 {
                    shiftSelectedWeek(by: 1)
                } else if value.translation.width >= 42 {
                    shiftSelectedWeek(by: -1)
                }
            }
    }

    private var monthCalendarDragGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width <= -42 {
                    shiftSelectedMonth(by: 1)
                } else if value.translation.width >= 42 {
                    shiftSelectedMonth(by: -1)
                }
            }
    }

    private func weekDayCell(for day: Date) -> some View {
        let summary = daySummary(for: day)
        let pending = summary.pendingCount
        let completed = summary.completedCount
        let total = pending + completed
        let completionRatio = total > 0 ? CGFloat(completed) / CGFloat(total) : 0
        let hasAnyWork = total > 0
        let isComplete = hasAnyWork && pending == 0
        let isInProgress = hasAnyWork && !isComplete
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDayStart)
        let isToday = calendar.isDateInToday(day)
        let activityIntensity = min(1, CGFloat(total) / 4.0)
        let baseFill: Color = {
            if isInProgress { return Theme.accent.opacity(0.12 + (0.34 * max(activityIntensity, completionRatio))) }
            if isComplete { return Theme.surface }
            return Theme.surface2
        }()
        let foreground: Color = Theme.text
        let borderColor: Color = {
            if isSelected { return Theme.accent }
            if isToday { return Theme.accent.opacity(0.4) }
            return Theme.textSecondary.opacity(0.18)
        }()
        let borderWidth: CGFloat = isSelected ? 1.8 : (isToday ? 1.2 : 1)
        let scale: CGFloat = isSelected ? 1.04 : (isToday ? 1.015 : 1.0)

        return Button {
            selectDay(day)
        } label: {
            VStack(spacing: Theme.Spacing.compact) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(isSelected ? foreground.opacity(0.85) : Theme.textSecondary)

                Text(day.formatted(.dateTime.day()))
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(foreground)

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Typography.iconSmall)
                        .foregroundStyle(Theme.success)
                } else {
                    Color.clear
                        .frame(height: 14)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(baseFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .scaleEffect(scale)
            .shadow(
                color: isSelected ? Theme.accent.opacity(0.22) : .clear,
                radius: isSelected ? 8 : 0,
                y: isSelected ? 3 : 0
            )
            .animation(.snappy(duration: 0.2), value: selectedDayStart)
        }
        .buttonStyle(PressableCalendarDayButtonStyle())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                jumpToReview(for: day)
            }
        )
    }

    private var captureToast: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("Added to Inbox")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            Spacer()

            if let task = toastTask, task.state == .inbox, selectedTodayTasks.count < todayCap {
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
        guard !addedToToday else {
            task.createdAt = assignmentTimestamp(for: selectedDayStart)
            try? modelContext.save()
            return
        }
        toastTask = task
        showingCaptureToast = true
        scheduleToastDismiss()
    }

    private func commitToToday(_ task: TaskItem) {
        guard task.state == .inbox, selectedTodayTasks.count < todayCap else { return }
        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.18)) {
            task.state = .today
            task.createdAt = assignmentTimestamp(for: selectedDayStart)
            showingCaptureToast = false
        }
        toastDismissWorkItem?.cancel()
        toastDismissWorkItem = nil
        try? modelContext.save()
    }

    private func assignmentTimestamp(for day: Date) -> Date {
        let nowComponents = calendar.dateComponents([.hour, .minute, .second], from: .now)
        return calendar.date(
            bySettingHour: nowComponents.hour ?? 12,
            minute: nowComponents.minute ?? 0,
            second: nowComponents.second ?? 0,
            of: day
        ) ?? day
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
    let dayTitle: String
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
                        Text("Nothing completed on \(dayTitle).")
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
