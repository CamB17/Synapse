import SwiftUI
import SwiftData
import UIKit
import Combine

struct TodayView: View {
    let taskNamespace: Namespace.ID
    @Binding var externalCaptureRequestID: Int
    @Binding var hideBottomNavigation: Bool

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

    @Query(sort: [SortDescriptor(\HabitCompletion.day, order: .reverse)])
    private var habitCompletions: [HabitCompletion]

    @Query(sort: [SortDescriptor(\HabitPausePeriod.startDay, order: .reverse)])
    private var habitPausePeriods: [HabitPausePeriod]

    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .reverse)])
    private var sessions: [FocusSession]

    @State private var showingCapture = false
    @State private var isFocusMode = false
    @State private var showLaterTasks = false
    @State private var focusTimeFilter: FocusTimeFilter = TodayView.initialFocusTimeFilter()
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var visibleMonthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? Calendar.current.startOfDay(for: .now)
    @State private var calendarMode: CalendarMode = .week
    @State private var lastObservedPartOfDay: TaskPartOfDay = TodayView.partOfDay(at: .now)
    @State private var monthSwipeOffset: CGFloat = 0
    @State private var monthPagerWidth: CGFloat = 1
    @State private var isMonthAnimating = false
    @State private var showingMonthYearPicker = false
    @State private var selectedDayDetail: DayDetailSelection?

    @State private var focusIsRunning = false
    @State private var focusElapsedSeconds = 0
    @State private var focusTimer: Timer?
    @State private var focusTaskSeconds: [UUID: Int] = [:]
    @State private var focusActiveTaskID: UUID?

    @State private var focusToastMessage = ""
    @State private var showingFocusToast = false
    @State private var focusToastWorkItem: DispatchWorkItem?
    @State private var daySyncAnchor = Calendar.current.startOfDay(for: .now)
    @State private var animatedCompletionRatio: CGFloat = 0
    @State private var headerProgressPulse = false
    @State private var headerCompletionGlow = false
    @State private var hasInitializedHeaderProgress = false
    @State private var didBackfillHabitCompletions = false
    private let partOfDayTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private struct DayDetailSelection: Identifiable {
        let day: Date
        var id: Date { day }
    }

    private enum FocusTimeFilter: String, CaseIterable {
        case morning
        case afternoon
        case evening
        case all

        var label: String {
            switch self {
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            case .all: return "All"
            }
        }
    }

    private static func partOfDay(at date: Date, calendar: Calendar = .current) -> TaskPartOfDay {
        let hour = calendar.component(.hour, from: date)
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }

    private static func initialFocusTimeFilter() -> FocusTimeFilter {
        switch partOfDay(at: .now) {
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .evening: return .evening
        case .anytime: return .all
        }
    }

    private enum CalendarMode: CaseIterable {
        case week
        case month

        var label: String {
            switch self {
            case .week: return "Week"
            case .month: return "Month"
            }
        }
    }

    private let todayCap = 5
    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var selectedDayStart: Date { calendar.startOfDay(for: selectedDate) }
    private var minNavigableMonth: Date {
        calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
    }
    private var maxNavigableMonth: Date {
        calendar.date(from: DateComponents(year: 2100, month: 12, day: 1)) ?? .distantFuture
    }
    private var currentMonthLabel: String {
        switch calendarMode {
        case .week:
            selectedDayStart.formatted(.dateTime.month(.abbreviated).year())
        case .month:
            visibleMonthStart.formatted(.dateTime.month(.wide).year())
        }
    }
    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDayStart) else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }
    private var weekdaySymbolsOrdered: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...]) + Array(symbols[..<start])
    }
    private var canNavigateToPreviousMonth: Bool {
        guard let previous = month(byAdding: -1, to: visibleMonthStart) else { return false }
        return previous >= minNavigableMonth
    }
    private var canNavigateToNextMonth: Bool {
        guard let next = month(byAdding: 1, to: visibleMonthStart) else { return false }
        return next <= maxNavigableMonth
    }
    private func monthGridDays(for monthStart: Date) -> [Date?] {
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
                guard let day = assignedDay(for: task) else { return false }
                return calendar.isDate(day, inSameDayAs: selectedDayStart)
            }
        )
    }

    private var filteredTasksForSelectedDay: [TaskItem] {
        guard isTodaySelectedDay else { return assignedTasksForSelectedDay }
        return assignedTasksForSelectedDay.filter(matchesFocusTimeFilter)
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

    private var todayRitualSummary: RitualDaySummary {
        ritualSummary(for: todayStart)
    }

    private var activeHabitCount: Int {
        todayRitualSummary.total
    }

    private var completedHabitCount: Int {
        todayRitualSummary.completed
    }

    private var allRitualsComplete: Bool {
        todayRitualSummary.isComplete
    }

    private var ritualCompletionRatio: CGFloat {
        selectedDayRitualSummary.ratio
    }

    private var selectedDayAllRitualsComplete: Bool {
        selectedDayRitualSummary.isComplete
    }

    private var headerTitle: String {
        formatHeaderTitle(selectedDayStart)
    }

    private var ritualProgressLine: String {
        guard selectedDayRitualSummary.total > 0 else {
            return isTodaySelectedDay ? "No rituals set yet" : "No rituals for this day."
        }
        if selectedDayRitualSummary.isComplete {
            return "Rituals complete."
        }
        return "\(selectedDayRitualSummary.completed) of \(selectedDayRitualSummary.total) rituals complete."
    }

    private var currentStreak: Int {
        guard !habits.isEmpty else { return 0 }

        let earliestHabitDay = habits
            .map { calendar.startOfDay(for: $0.createdAt) }
            .min() ?? todayStart

        var streak = 0
        var cursor = todayStart
        var scannedDays = 0

        while cursor >= earliestHabitDay && scannedDays < 3650 {
            let summary = ritualSummary(for: cursor)
            if summary.total == 0 {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
                scannedDays += 1
                continue
            }
            guard summary.isComplete else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            scannedDays += 1
        }
        return streak
    }

    private var headerMomentumLine: String? {
        guard isTodaySelectedDay else { return nil }
        switch streakPresentation {
        case .ongoing(let day):
            return "Streak: Day \(day)"
        case .freshStart:
            return "New streak"
        case .restart:
            return "New streak begins."
        }
    }

    private var streakPresentation: StreakPresentation {
        if currentStreak > 0 {
            return .ongoing(currentStreak)
        }
        return hasAnyCompletedRitualDay ? .restart : .freshStart
    }

    private var completionAffirmationLine: String? {
        guard isTodaySelectedDay, allRitualsComplete else { return nil }
        let options = [
            "Consistency builds identity.",
            "Another day aligned.",
            "You kept your word to yourself."
        ]
        return options[dayRotationSeed % options.count]
    }

    private var hasAnyCompletedRitualDay: Bool {
        let completedDays = Set(habitCompletions.map { calendar.startOfDay(for: $0.day) })
        return completedDays.contains { day in
            day < todayStart && ritualSummary(for: day).isComplete
        }
    }

    private var totalFocusSecondsSelectedDay: Int {
        let end = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) ?? .distantFuture
        let logged = sessions
            .filter { $0.startedAt >= selectedDayStart && $0.startedAt < end }
            .reduce(0) { $0 + $1.durationSeconds }
        return logged + (calendar.isDateInToday(selectedDayStart) ? focusElapsedSeconds : 0)
    }

    private enum SelectedDayRelation {
        case past
        case today
        case future
    }

    private var selectedDayRelation: SelectedDayRelation {
        if isToday(selectedDayStart) {
            return .today
        }
        return isFuture(selectedDayStart) ? .future : .past
    }

    private var isTodaySelectedDay: Bool {
        selectedDayRelation == .today
    }

    private var activeHabitsForSelectedDay: [Habit] {
        habits.filter { isHabit($0, activeOn: selectedDayStart) }
    }

    private var completedHabitIDsForSelectedDay: Set<UUID> {
        Set(
            habitCompletions
                .filter { calendar.isDate($0.day, inSameDayAs: selectedDayStart) }
                .map(\.habitId)
        )
    }

    private var selectedDayRitualSummary: RitualDaySummary {
        ritualSummary(for: selectedDayStart)
    }

    private var selectedDayStatusLine: String {
        switch selectedDayRelation {
        case .future:
            return "Upcoming"
        case .today, .past:
            if selectedDayRitualSummary.isComplete {
                return "Rituals complete."
            }
            if selectedDayRitualSummary.total == 0 {
                return "0 rituals kept"
            }
            return "\(selectedDayRitualSummary.completed) of \(selectedDayRitualSummary.total) rituals complete"
        }
    }

    private var currentPartOfDay: TaskPartOfDay {
        Self.partOfDay(at: .now, calendar: calendar)
    }

    private var dayRotationSeed: Int {
        calendar.ordinality(of: .day, in: .year, for: todayStart) ?? 0
    }

    private struct RitualDaySummary {
        let total: Int
        let completed: Int

        var isComplete: Bool {
            total > 0 && completed == total
        }

        var ratio: CGFloat {
            guard total > 0 else { return 0 }
            return CGFloat(completed) / CGFloat(total)
        }
    }

    private enum StreakPresentation {
        case ongoing(Int)
        case freshStart
        case restart
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas(daySeed: daySyncAnchor) {
                ZStack(alignment: .bottomTrailing) {
                    if !isFocusMode {
                        ScrollView {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                header
                                calendarRail
                                dayContentPanel

                                Spacer(minLength: 88)
                            }
                            .padding(Theme.Spacing.md)
                        }
                        .transition(.opacity)
                    }

                    if isFocusMode {
                        immersiveFocusLayer
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if !isFocusMode {
                        floatingFocusButton
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

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
            .toolbar(isFocusMode ? .hidden : .visible, for: .navigationBar)
            .sheet(isPresented: $showingCapture) {
                QuickCaptureSheet(
                    placeholder: "Capture something…",
                    canAssignDefaultDay: assignedTasksForSelectedDay.count < todayCap,
                    defaultAssignmentDay: selectedDayStart,
                    onAdded: { task, addedToToday in
                        handleCapturedTask(task, addedToToday: addedToToday)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedDayDetail) { selection in
                DayDetailView(day: selection.day)
                    .presentationDetents([.fraction(0.68), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingMonthYearPicker) {
                MonthYearPickerSheet(
                    selectedMonthStart: visibleMonthStart,
                    minYear: calendar.component(.year, from: minNavigableMonth),
                    maxYear: calendar.component(.year, from: maxNavigableMonth)
                ) { pickedMonth in
                    guard canNavigate(to: pickedMonth) else { return }
                    withAnimation(.snappy(duration: 0.24)) {
                        visibleMonthStart = pickedMonth
                    }
                }
            }
            .onAppear {
                backfillHabitCompletionsIfNeeded()
                synchronizeDayState()
                synchronizeFocusFilterWithCurrentPartOfDay(force: true)
                hideBottomNavigation = isFocusMode
                animatedCompletionRatio = ritualCompletionRatio
                hasInitializedHeaderProgress = true
                visibleMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDayStart)) ?? selectedDayStart
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                synchronizeDayState()
                synchronizeFocusFilterWithCurrentPartOfDay(force: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                synchronizeDayState()
                synchronizeFocusFilterWithCurrentPartOfDay(force: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                synchronizeDayState()
                synchronizeFocusFilterWithCurrentPartOfDay(force: true)
            }
            .onReceive(partOfDayTicker) { _ in
                guard scenePhase == .active else { return }
                synchronizeFocusFilterWithCurrentPartOfDay()
            }
            .onChange(of: externalCaptureRequestID) { _, _ in
                showingCapture = true
            }
            .onChange(of: isFocusMode) { _, isEnabled in
                if isEnabled, focusActiveTaskID == nil {
                    focusActiveTaskID = highPriorityTasks.first?.id
                }
                if isEnabled, !focusIsRunning {
                    startFocusTimer()
                }
                hideBottomNavigation = isEnabled
            }
            .onChange(of: calendarMode) { _, newMode in
                guard newMode == .month else { return }
                visibleMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDayStart)) ?? selectedDayStart
            }
            .onChange(of: selectedDayStart) { _, _ in
                showLaterTasks = false
                if let current = focusActiveTaskID,
                   !assignedTasksForSelectedDay.contains(where: { $0.id == current }) {
                    focusActiveTaskID = highPriorityTasks.first?.id
                }
                if calendarMode == .month {
                    visibleMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDayStart)) ?? selectedDayStart
                }
                animateHeaderForSelectedDateChange()
            }
            .onChange(of: completedHabitCount) { oldValue, newValue in
                guard isTodaySelectedDay else { return }
                guard oldValue != newValue else { return }
                animateHeaderProgress(triggerSuccess: newValue > oldValue && allRitualsComplete)
            }
            .onChange(of: activeHabitCount) { oldValue, newValue in
                guard isTodaySelectedDay else { return }
                guard oldValue != newValue else { return }
                animateHeaderProgress(triggerSuccess: false)
            }
            .onDisappear {
                focusTimer?.invalidate()
                focusTimer = nil
                hideBottomNavigation = false
            }
            .animation(.snappy(duration: 0.18), value: showingFocusToast)
            .animation(.easeInOut(duration: 0.32), value: isFocusMode)
            .animation(.snappy(duration: 0.18), value: showLaterTasks)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Button {
                        returnToTodayFromHeader()
                    } label: {
                        Text(headerTitle)
                            .font(Theme.Typography.titleLarge)
                            .foregroundStyle(Theme.text)
                            .contentTransition(.opacity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isTodaySelectedDay)
                    .accessibilityLabel(isTodaySelectedDay ? "Today" : "Return to Today")

                    if !isTodaySelectedDay {
                        Text("Tap to return to Today")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary.opacity(0.72))
                            .transition(.opacity)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    let haptic = UIImpactFeedbackGenerator(style: .soft)
                    haptic.impactOccurred()
                    toggleFocusMode()
                } label: {
                    Label("Focus", systemImage: "timer")
                        .font(Theme.Typography.bodySmallStrong)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Theme.accent.opacity(0.12))
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Theme.accent.opacity(0.26), lineWidth: 0.8)
                        }
                        .shadow(color: Theme.cardShadow().opacity(0.7), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Theme.surface2.opacity(0.92))

                GeometryReader { proxy in
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.accent.opacity(0.95),
                                    Theme.accent2.opacity(0.86)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, proxy.size.width * animatedCompletionRatio))
                }
            }
            .frame(height: 9)
            .overlay {
                if selectedDayAllRitualsComplete || (isTodaySelectedDay && headerCompletionGlow) {
                    Capsule(style: .continuous)
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 0.9)
                        .shadow(
                            color: Theme.accent.opacity(headerCompletionGlow ? 0.36 : 0.18),
                            radius: headerCompletionGlow ? 8 : 4
                        )
                    }
            }
            .animation(.easeInOut(duration: 0.24), value: animatedCompletionRatio)

            Text(ritualProgressLine)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText())

            if let headerMomentumLine {
                Text(headerMomentumLine)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary.opacity(0.78))
                    .contentTransition(.numericText())
            }

            if let completionAffirmationLine {
                Text(completionAffirmationLine)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.72))
            }
        }
        .padding(.horizontal, Theme.Spacing.cardInset)
        .padding(.vertical, 10)
        .scaleEffect(headerProgressPulse ? 1.01 : 1, anchor: .top)
        .background(
            headerBackground,
            in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
        )
        .shadow(color: Theme.cardShadow().opacity(0.85), radius: Theme.shadowRadius, y: Theme.shadowY)
        .animation(.easeInOut(duration: 0.2), value: selectedDayStart)
    }

    private var calendarRail: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            calendarHeader

            calendarModeControl

            if calendarMode == .week {
                weekStrip
            } else {
                monthHeatmapPager
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
        }
        .padding(Theme.Spacing.sm)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
        .animation(.snappy(duration: 0.22), value: calendarMode)
    }

    private var calendarHeader: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if calendarMode == .month {
                Button {
                    shiftVisibleMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(canNavigateToPreviousMonth ? Theme.textSecondary : Theme.textSecondary.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(Theme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateToPreviousMonth || isMonthAnimating)
            }

            Button {
                if calendarMode == .month {
                    showingMonthYearPicker = true
                }
            } label: {
                HStack(spacing: Theme.Spacing.xxs) {
                    Text(currentMonthLabel)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary.opacity(0.92))

                    if calendarMode == .month {
                        Image(systemName: "chevron.down")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary.opacity(0.75))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(calendarMode == .month ? "Choose month and year" : currentMonthLabel)

            Spacer(minLength: 0)

            if calendarMode == .month {
                Button {
                    shiftVisibleMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(canNavigateToNextMonth ? Theme.textSecondary : Theme.textSecondary.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(Theme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateToNextMonth || isMonthAnimating)
            }
        }
    }

    private var calendarModeControl: some View {
        HStack(spacing: Theme.Spacing.xxxs) {
            ForEach(CalendarMode.allCases, id: \.self) { mode in
                Button {
                    guard calendarMode != mode else { return }
                    withAnimation(.snappy(duration: 0.18)) {
                        calendarMode = mode
                    }
                } label: {
                    Text(mode.label)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(calendarMode == mode ? Theme.text : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(calendarMode == mode ? Theme.surface : .clear)
                                .shadow(
                                    color: calendarMode == mode ? Theme.cardShadow().opacity(0.9) : .clear,
                                    radius: 4,
                                    y: 2
                                )
                        )
                        .scaleEffect(calendarMode == mode ? 1 : 0.985)
                        .opacity(calendarMode == mode ? 1 : 0.88)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface2.opacity(0.92))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.textSecondary.opacity(0.12), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.16), value: calendarMode)
    }

    private var weekStrip: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(weekDays, id: \.self) { day in
                weekDayTile(for: day)
            }
        }
    }

    private func weekDayTile(for day: Date) -> some View {
        let summary = ritualSummary(for: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDayStart)
        let tileState = tileState(for: day, summary: summary)
        let completionState = weekStripCompletionState(for: day, summary: summary)
        let isToday = calendar.isDate(day, inSameDayAs: todayStart)

        return Button {
            selectDayInline(day)
        } label: {
            VStack(spacing: Theme.Spacing.xxs) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(Theme.Typography.caption.weight(.medium))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)

                Text(day.formatted(.dateTime.day()))
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tileState.fill)
                    .overlay {
                        if let tintOpacity = weekStripCompletionTintOpacity(for: completionState, isSelected: isSelected) {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Theme.accent.opacity(tintOpacity))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(
                                isSelected ? Theme.accent.opacity(0.68) : (isToday ? Theme.accent.opacity(0.32) : tileState.stroke),
                                lineWidth: isSelected ? 1 : 0.8
                            )
                    }
                    .overlay {
                        if let ring = weekStripCompletionRing(for: completionState, isSelected: isSelected) {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(ring.color, lineWidth: ring.width)
                                .padding(1)
                        }
                    }
            )
        }
        .buttonStyle(.plain)
    }

    private var monthHeatmapPager: some View {
        VStack(spacing: Theme.Spacing.xs) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: Theme.Spacing.xxs) {
                ForEach(weekdaySymbolsOrdered, id: \.self) { symbol in
                    Text(symbol)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let fadeProgress = Double(min(CGFloat(1), abs(monthSwipeOffset) / width))
                let previousMonth = month(byAdding: -1, to: visibleMonthStart) ?? visibleMonthStart
                let nextMonth = month(byAdding: 1, to: visibleMonthStart) ?? visibleMonthStart

                HStack(spacing: 0) {
                    monthGrid(for: previousMonth)
                        .frame(width: width)
                    monthGrid(for: visibleMonthStart)
                        .frame(width: width)
                    monthGrid(for: nextMonth)
                        .frame(width: width)
                }
                .offset(x: -width + monthSwipeOffset)
                .opacity(0.94 + (0.06 * (1 - fadeProgress)))
                .gesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { value in
                            guard !isMonthAnimating else { return }
                            monthPagerWidth = width
                            monthSwipeOffset = value.translation.width
                        }
                        .onEnded { value in
                            guard !isMonthAnimating else { return }
                            let predicted = value.predictedEndTranslation.width
                            let travel = abs(predicted) > abs(value.translation.width) ? predicted : value.translation.width
                            let threshold = width * 0.24

                            if travel <= -threshold {
                                shiftVisibleMonth(by: 1)
                            } else if travel >= threshold {
                                shiftVisibleMonth(by: -1)
                            } else {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                    monthSwipeOffset = 0
                                }
                            }
                        }
                )
                .onAppear {
                    monthPagerWidth = width
                }
                .onChange(of: width) { _, newValue in
                    monthPagerWidth = max(newValue, 1)
                }
            }
            .frame(height: monthPagerHeight)
            .clipped()

            HStack(spacing: Theme.Spacing.xs) {
                Text("Less")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.74))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tileFill(for: .none))
                    .frame(width: 18, height: 8)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tileFill(for: .partial))
                    .frame(width: 18, height: 8)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tileFill(for: .full))
                    .frame(width: 18, height: 8)

                Text("More")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.74))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func monthGrid(for monthStart: Date) -> some View {
        let days = monthGridDays(for: monthStart)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    monthCell(for: day)
                } else {
                    Color.clear
                        .frame(height: 34)
                }
            }
        }
    }

    private func monthCell(for day: Date) -> some View {
        let summary = ritualSummary(for: day)
        let tileState = tileState(for: day, summary: summary)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDayStart)
        let isToday = calendar.isDate(day, inSameDayAs: todayStart)

        return Button {
            openDayDetail(for: day)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tileState.fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isSelected ? Theme.accent.opacity(0.72) : (isToday ? Theme.accent.opacity(0.34) : tileState.stroke),
                                lineWidth: isSelected ? 1.1 : 0.8
                            )
                    }

                Text(day.formatted(.dateTime.day()))
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(tileState.label)
            }
            .frame(height: 34)
        }
        .buttonStyle(.plain)
    }

    private enum CalendarTileState {
        case none
        case partial
        case full
        case future

        var fill: Color {
            switch self {
            case .none:
                return Theme.surface2.opacity(0.72)
            case .partial:
                return Theme.accent.opacity(0.24)
            case .full:
                return Theme.accent.opacity(0.62)
            case .future:
                return Theme.surface2.opacity(0.56)
            }
        }

        var stroke: Color {
            switch self {
            case .none:
                return Theme.textSecondary.opacity(0.12)
            case .partial:
                return Theme.accent.opacity(0.34)
            case .full:
                return Theme.accent.opacity(0.55)
            case .future:
                return Theme.textSecondary.opacity(0.10)
            }
        }

        var label: Color {
            switch self {
            case .full:
                return Theme.text
            case .partial:
                return Theme.text
            case .none, .future:
                return Theme.textSecondary
            }
        }
    }

    private enum WeekStripCompletionState {
        case none
        case partial
        case full
        case future
    }

    private struct CompletionRingStyle {
        let color: Color
        let width: CGFloat
    }

    private func tileFill(for state: CalendarTileState) -> Color {
        state.fill
    }

    private func tileState(for day: Date, summary: RitualDaySummary) -> CalendarTileState {
        if day > todayStart {
            return .future
        }
        if summary.isComplete {
            return .full
        }
        if summary.completed > 0 {
            return .partial
        }
        return .none
    }

    private func totalRituals(_ date: Date) -> Int {
        ritualSummary(for: date).total
    }

    private func completedRituals(_ date: Date) -> Int {
        ritualSummary(for: date).completed
    }

    private func allRitualsComplete(_ date: Date) -> Bool {
        let total = totalRituals(date)
        return total > 0 && completedRituals(date) == total
    }

    private func weekStripCompletionState(for day: Date, summary: RitualDaySummary) -> WeekStripCompletionState {
        if isFuture(day) {
            return .future
        }
        if allRitualsComplete(day) {
            return .full
        }
        if summary.completed > 0 {
            return .partial
        }
        return .none
    }

    private func weekStripCompletionTintOpacity(for state: WeekStripCompletionState, isSelected: Bool) -> Double? {
        guard !isSelected else { return nil }
        switch state {
        case .full:
            return 0.08
        case .partial:
            return 0.03
        case .none, .future:
            return nil
        }
    }

    private func weekStripCompletionRing(for state: WeekStripCompletionState, isSelected: Bool) -> CompletionRingStyle? {
        guard !isSelected else { return nil }
        switch state {
        case .full:
            return CompletionRingStyle(color: Theme.accent.opacity(0.38), width: 1.2)
        case .partial:
            return CompletionRingStyle(color: Theme.accent.opacity(0.2), width: 0.9)
        case .none, .future:
            return nil
        }
    }

    private func monthGridHeight(for monthStart: Date) -> CGFloat {
        let rows = max(1, monthGridDays(for: monthStart).count / 7)
        return CGFloat(rows) * 40
    }

    private var monthPagerHeight: CGFloat {
        let previous = month(byAdding: -1, to: visibleMonthStart) ?? visibleMonthStart
        let next = month(byAdding: 1, to: visibleMonthStart) ?? visibleMonthStart
        return max(
            monthGridHeight(for: previous),
            monthGridHeight(for: visibleMonthStart),
            monthGridHeight(for: next)
        )
    }

    private func month(byAdding value: Int, to date: Date) -> Date? {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        guard let candidate = calendar.date(byAdding: .month, value: value, to: start) else { return nil }
        let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: candidate)) ?? candidate
        return normalized
    }

    private func canNavigate(to month: Date) -> Bool {
        month >= minNavigableMonth && month <= maxNavigableMonth
    }

    private func shiftVisibleMonth(by delta: Int) {
        guard delta != 0, !isMonthAnimating else { return }
        guard let target = month(byAdding: delta, to: visibleMonthStart), canNavigate(to: target) else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                monthSwipeOffset = 0
            }
            return
        }

        let travel = max(1, monthPagerWidth)
        isMonthAnimating = true
        withAnimation(.easeInOut(duration: 0.24)) {
            monthSwipeOffset = delta > 0 ? -travel : travel
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                visibleMonthStart = target
                monthSwipeOffset = 0
            }
            isMonthAnimating = false
        }
    }

    private func selectDayInline(_ day: Date) {
        let normalized = calendar.startOfDay(for: day)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = normalized
        }
    }

    private func openDayDetail(for day: Date) {
        let normalized = calendar.startOfDay(for: day)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = normalized
            selectedDayDetail = DayDetailSelection(day: normalized)
        }
    }

    private var headerBackground: some ShapeStyle {
        let completionGlow = (selectedDayAllRitualsComplete || (isTodaySelectedDay && headerCompletionGlow)) ? 0.12 : 0.04
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Theme.surface,
                    Theme.surface2.opacity(0.55),
                    Theme.accent.opacity(completionGlow)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func animateHeaderProgress(triggerSuccess: Bool) {
        guard hasInitializedHeaderProgress else {
            animatedCompletionRatio = ritualCompletionRatio
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            animatedCompletionRatio = ritualCompletionRatio
        }
        withAnimation(.snappy(duration: 0.18)) {
            headerProgressPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            headerProgressPulse = false
        }

        guard triggerSuccess else { return }
        let feedback = UIImpactFeedbackGenerator(style: .soft)
        feedback.impactOccurred()

        withAnimation(.easeOut(duration: 0.2)) {
            headerCompletionGlow = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            withAnimation(.easeInOut(duration: 0.24)) {
                headerCompletionGlow = false
            }
        }
    }

    private func animateHeaderForSelectedDateChange() {
        withAnimation(.easeInOut(duration: 0.24)) {
            animatedCompletionRatio = ritualCompletionRatio
        }
    }

    private func returnToTodayFromHeader() {
        guard !isTodaySelectedDay else { return }
        let feedback = UIImpactFeedbackGenerator(style: .soft)
        feedback.impactOccurred()

        let target = todayStart
        withAnimation(.easeInOut(duration: 0.24)) {
            selectedDate = target
            if calendarMode == .month {
                visibleMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: target)) ?? target
            }
        }
    }

    private var dayContentPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedDayStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)

                Spacer(minLength: 0)

                Text(selectedDayStatusLine)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.88))
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Rituals")
                    .font(Theme.Typography.sectionLabel)
                    .tracking(Theme.Typography.sectionTracking)
                    .foregroundStyle(Theme.textSecondary.opacity(0.88))

                if activeHabitsForSelectedDay.isEmpty {
                    Text("No rituals for this day.")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, Theme.Spacing.xxs)
                } else {
                    VStack(spacing: Theme.Spacing.xxs) {
                        ForEach(activeHabitsForSelectedDay) { habit in
                            ritualRow(for: habit)
                        }
                    }
                }
            }

            Rectangle()
                .fill(Theme.textSecondary.opacity(0.12))
                .frame(height: 0.8)
                .padding(.vertical, Theme.Spacing.xxxs)

            supportSectionContent
                .transition(.opacity)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
        .animation(.easeInOut(duration: 0.22), value: selectedDayStart)
    }

    private func ritualRow(for habit: Habit) -> some View {
        let isCompleted = completedHabitIDsForSelectedDay.contains(habit.id)
        return Button {
            toggleRitualForSelectedDay(habit)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : (selectedDayRelation == .future ? "circle.dashed" : "circle"))
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary.opacity(selectedDayRelation == .future ? 0.5 : 0.74))

                Text(habit.title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(isCompleted ? "Done" : "Not done")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.82))
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface.opacity(0.75))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.textSecondary.opacity(0.1), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private var supportSectionContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Support")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.82))

                Text(formatMinutes(totalFocusSecondsSelectedDay))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.72))
                    .contentTransition(.numericText())

                Spacer(minLength: 0)
            }

            if let carriedForwardLine, isTodaySelectedDay {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "arrow.trianglehead.clockwise")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    Text(carriedForwardLine)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if isTodaySelectedDay {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "sun.max")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.82))
                    Text("Now: \(partOfDayLabel(currentPartOfDay))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(FocusTimeFilter.allCases, id: \.self) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    focusTimeFilter = option
                                    showLaterTasks = false
                                }
                            } label: {
                                Text(option.label)
                                    .font(Theme.Typography.caption.weight(.medium))
                                    .foregroundStyle(focusTimeFilter == option ? Theme.accent : Theme.textSecondary)
                                    .padding(.horizontal, Theme.Spacing.xs)
                                    .padding(.vertical, Theme.Spacing.xxxs)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(focusTimeFilter == option ? Theme.accent.opacity(0.11) : Theme.surface2.opacity(0.82))
                                    )
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .stroke(
                                                focusTimeFilter == option ? Theme.accent.opacity(0.34) : Theme.textSecondary.opacity(0.12),
                                                lineWidth: 0.9
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                if focusTimeFilter == .all {
                    Text("All tasks for this day")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.72))
                }
            }

            if isTodaySelectedDay, highPriorityTasks.count > 5 {
                Text("Consider keeping Focus tasks to 3-5.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if visibleFocusTasks.isEmpty {
                EmptyStatePanel(
                    symbol: "checklist",
                    title: isTodaySelectedDay ? "No tasks yet" : "No tasks assigned",
                    subtitle: isTodaySelectedDay ? "Use + to schedule your next task." : "Nothing scheduled for this day."
                )
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(visibleFocusTasks) { task in
                        FocusTaskRow(
                            task: task,
                            namespace: taskNamespace,
                            isActive: isFocusMode && focusActiveTaskID == task.id,
                            canComplete: isTodaySelectedDay,
                            onSelect: {
                                withAnimation(.snappy(duration: 0.16)) {
                                    focusActiveTaskID = task.id
                                }
                            },
                            onComplete: {
                                guard isTodaySelectedDay else { return }
                                complete(task)
                            },
                            onSetPriority: { priority in
                                withAnimation(.snappy(duration: 0.16)) {
                                    task.priority = priority
                                }
                                try? modelContext.save()
                            }
                        )
                    }
                }
                .transition(.opacity)
                .id("\(selectedDayStart.timeIntervalSince1970)-\(focusTimeFilter.rawValue)")
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
        .animation(.easeInOut(duration: 0.2), value: focusTimeFilter)
    }

    private var immersiveFocusLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.surface,
                    Theme.accent.opacity(0.16),
                    Theme.surface2.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 86)

                Text(activeFocusTask?.title ?? "Choose one thing.")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 340)

                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.08))
                        .frame(width: 206, height: 206)
                    Text(timeString(focusElapsedSeconds))
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                }

                Button {
                    handleImmersiveFocusPrimaryAction()
                } label: {
                    Text(immersiveFocusPrimaryTitle)
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.accent, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 42)

                Spacer(minLength: 88)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    private var immersiveFocusPrimaryTitle: String {
        if focusIsRunning || focusElapsedSeconds == 0 { return "Pause" }
        return "End Focus"
    }

    private func handleImmersiveFocusPrimaryAction() {
        if focusIsRunning {
            pauseFocusTimer()
            return
        }

        if focusElapsedSeconds > 0 {
            endFocusSession()
            withAnimation(.snappy(duration: 0.24)) {
                isFocusMode = false
            }
            return
        }

        startFocusTimer()
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
                Text("Choose one thing.")
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
        guard isTodaySelectedDay, task.state == .today else { return }

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

    private func toggleRitualForSelectedDay(_ habit: Habit) {
        switch selectedDayRelation {
        case .past:
            return
        case .future:
            showToast("Rituals can be completed on the day.")
            return
        case .today:
            break
        }

        let isCompleted = completedHabitIDsForSelectedDay.contains(habit.id)
        let haptic = UIImpactFeedbackGenerator(style: isCompleted ? .soft : .light)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.16)) {
            if isCompleted {
                habit.uncompleteToday()
                removeCompletionRecord(for: habit.id, on: selectedDayStart)
            } else {
                habit.completeToday()
                ensureCompletionRecord(for: habit.id, on: selectedDayStart)
            }
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
        showToast("Logged \(minutes) min")
    }

    private func showToast(_ message: String) {
        focusToastWorkItem?.cancel()
        focusToastMessage = message

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

    private func synchronizeDayState() {
        let currentDay = todayStart
        let dayChanged = !calendar.isDate(currentDay, inSameDayAs: daySyncAnchor)

        if dayChanged {
            if focusIsRunning {
                pauseFocusTimer()
            }

            focusElapsedSeconds = 0
            focusTaskSeconds = [:]
            focusActiveTaskID = nil

            withAnimation(.snappy(duration: 0.24)) {
                daySyncAnchor = currentDay
                selectedDate = currentDay
                visibleMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDay)) ?? currentDay
                calendarMode = .week
                showLaterTasks = false
            }
        } else {
            daySyncAnchor = currentDay
        }

        rollForwardUnfinishedTasksIfNeeded()
    }

    private func rollForwardUnfinishedTasksIfNeeded() {
        var didChange = false

        for task in todayTasks {
            guard let day = assignedDay(for: task) else { continue }

            if day < todayStart {
                task.carriedOverFrom = day
                task.assignedDate = todayStart
                didChange = true
                continue
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

    private func ritualSummary(for day: Date) -> RitualDaySummary {
        let target = calendar.startOfDay(for: day)
        let activeForDay = habits.filter { isHabit($0, activeOn: target) }
        guard !activeForDay.isEmpty else { return RitualDaySummary(total: 0, completed: 0) }

        let completedIDs = Set(
            habitCompletions
                .filter { calendar.isDate($0.day, inSameDayAs: target) }
                .map(\.habitId)
        )
        let completedCount = activeForDay.reduce(0) { partial, habit in
            partial + (completedIDs.contains(habit.id) ? 1 : 0)
        }

        return RitualDaySummary(total: activeForDay.count, completed: completedCount)
    }

    private func isHabit(_ habit: Habit, activeOn day: Date) -> Bool {
        RitualAnalytics.isHabit(
            habit,
            activeOn: day,
            today: todayStart,
            pausePeriods: habitPausePeriods,
            calendar: calendar
        )
    }

    private func backfillHabitCompletionsIfNeeded() {
        guard !didBackfillHabitCompletions else { return }
        didBackfillHabitCompletions = true

        var didInsert = false
        for habit in habits {
            guard let lastCompletedDate = habit.lastCompletedDate else { continue }
            let day = calendar.startOfDay(for: lastCompletedDate)
            let exists = habitCompletions.contains {
                $0.habitId == habit.id && calendar.isDate($0.day, inSameDayAs: day)
            }
            guard !exists else { continue }
            modelContext.insert(HabitCompletion(habitId: habit.id, day: day, completedAt: lastCompletedDate))
            didInsert = true
        }

        if didInsert {
            try? modelContext.save()
        }
    }

    private func ensureCompletionRecord(for habitID: UUID, on day: Date) {
        let target = calendar.startOfDay(for: day)
        guard !habitCompletions.contains(where: { $0.habitId == habitID && calendar.isDate($0.day, inSameDayAs: target) }) else {
            return
        }
        modelContext.insert(HabitCompletion(habitId: habitID, day: target))
    }

    private func removeCompletionRecord(for habitID: UUID, on day: Date) {
        let target = calendar.startOfDay(for: day)
        for completion in habitCompletions where completion.habitId == habitID && calendar.isDate(completion.day, inSameDayAs: target) {
            modelContext.delete(completion)
        }
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

    private func focusFilter(for partOfDay: TaskPartOfDay) -> FocusTimeFilter {
        switch partOfDay {
        case .morning: return .morning
        case .afternoon: return .afternoon
        case .evening: return .evening
        case .anytime: return .all
        }
    }

    private func synchronizeFocusFilterWithCurrentPartOfDay(force: Bool = false) {
        let current = currentPartOfDay
        let didPartOfDayChange = current != lastObservedPartOfDay
        guard force || didPartOfDayChange else { return }

        lastObservedPartOfDay = current
        let targetFilter = focusFilter(for: current)
        guard focusTimeFilter != targetFilter else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            focusTimeFilter = targetFilter
            showLaterTasks = false
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

    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(calendar.startOfDay(for: date), inSameDayAs: todayStart)
    }

    private func isFuture(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) > todayStart
    }

    private func formatHeaderTitle(_ date: Date) -> String {
        if isToday(date) {
            return "Today"
        }
        return calendar.startOfDay(for: date).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func assignedDay(for task: TaskItem) -> Date? {
        guard let assignedDate = task.assignedDate else { return nil }
        return calendar.startOfDay(for: assignedDate)
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

}

private struct FocusTaskRow: View {
    let task: TaskItem
    let namespace: Namespace.ID
    let isActive: Bool
    let canComplete: Bool
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onSetPriority: (TaskPriority) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(priorityTone(for: task.priority))
                .frame(width: 1.5, height: 30)

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

            if canComplete {
                Button {
                    onComplete()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(Theme.Typography.iconLarge)
                        .foregroundStyle(Theme.textSecondary.opacity(0.9))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: task.state == .completed ? "checkmark.circle.fill" : "circle")
                    .font(Theme.Typography.iconLarge)
                    .foregroundStyle(task.state == .completed ? Theme.accent.opacity(0.72) : Theme.textSecondary.opacity(0.45))
            }
        }
        .padding(.horizontal, Theme.Spacing.xxxs)
        .padding(.vertical, Theme.Spacing.compact)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(isActive ? Theme.accent.opacity(0.04) : Color.clear)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .stroke(isActive ? Theme.accent.opacity(0.2) : .clear, lineWidth: 0.8)
        }
        .matchedGeometryEffect(id: task.id, in: namespace)
        .contentShape(Rectangle())
        .contextMenu {
            if canComplete {
                Button("Complete", systemImage: "checkmark") { onComplete() }
            }
            Button(TaskPriority.high.displayLabel) { onSetPriority(.high) }
            Button(TaskPriority.medium.displayLabel) { onSetPriority(.medium) }
            Button(TaskPriority.low.displayLabel) { onSetPriority(.low) }
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
            return Theme.accent.opacity(0.62)
        case .medium:
            return Theme.textSecondary.opacity(0.28)
        case .low:
            return Theme.textSecondary.opacity(0.14)
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
