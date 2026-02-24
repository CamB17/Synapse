import SwiftData
import SwiftUI
import UserNotifications

enum OnboardingStep: Equatable {
    case goals
    case notifications
    case calendarIntro
    case calendarSelect
    case routineTimeBlocks
    case routinePicker(HabitTimeBlock)
    case finish
}

struct OnboardingCoordinator: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\UserPreferences.createdAt, order: .forward)])
    private var preferenceRecords: [UserPreferences]

    @Query(sort: [SortDescriptor(\CalendarSyncSettings.createdAt, order: .forward)])
    private var syncSettingsRecords: [CalendarSyncSettings]

    @Query(sort: [SortDescriptor(\Habit.sortOrder, order: .reverse)])
    private var habits: [Habit]

    let onCompleted: () -> Void

    @StateObject private var appointmentSyncService = AppointmentSyncService()

    @State private var step: OnboardingStep = .goals
    @State private var isForward = true

    @State private var selectedGoals: Set<OnboardingGoal> = []
    @State private var notificationsEnabled = false

    @State private var calendarState: CalendarIntegrationState = .notConfigured
    @State private var selectedProviders: Set<CalendarProviderChoice> = []
    @State private var selectedCalendarIDs: Set<String> = []
    @State private var appleCalendars: [AvailableAppleCalendar] = []
    @State private var didLoadAppleCalendars = false

    @State private var selectedTimeBlocks: Set<HabitTimeBlock> = []
    @State private var selectedHabitTemplates: [HabitTimeBlock: Set<String>] = [:]
    @State private var showingCustomHabitInputForBlocks: Set<HabitTimeBlock> = []
    @State private var customHabitDraftByBlock: [HabitTimeBlock: String] = [:]

    @State private var isPersisting = false

    private struct CalendarOption: Identifiable, Hashable {
        let id: String
        let title: String
        let section: String
        let provider: CalendarProviderChoice
        let rawCalendarID: String
    }

    private enum NotificationChoice {
        case enabled
        case disabled
    }

    private var orderedTimeBlocks: [HabitTimeBlock] {
        HabitTimeBlock.allCases.filter { selectedTimeBlocks.contains($0) }
    }

    private var flowSteps: [OnboardingStep] {
        var output: [OnboardingStep] = [
            .goals,
            .notifications,
            .calendarIntro,
            .calendarSelect,
            .routineTimeBlocks
        ]

        output.append(contentsOf: orderedTimeBlocks.map { .routinePicker($0) })
        output.append(.finish)
        return output
    }

    private var progressValue: Double {
        let totalSlots = 5 + HabitTimeBlock.allCases.count + 1

        switch step {
        case .goals:
            return progress(slot: 1, totalSlots: totalSlots)
        case .notifications:
            return progress(slot: 2, totalSlots: totalSlots)
        case .calendarIntro:
            return progress(slot: 3, totalSlots: totalSlots)
        case .calendarSelect:
            return progress(slot: 4, totalSlots: totalSlots)
        case .routineTimeBlocks:
            return progress(slot: 5, totalSlots: totalSlots)
        case let .routinePicker(block):
            let pickerIndex = orderedTimeBlocks.firstIndex(of: block) ?? 0
            return progress(slot: 6 + pickerIndex, totalSlots: totalSlots)
        case .finish:
            return progress(slot: totalSlots, totalSlots: totalSlots)
        }
    }

    private var groupedCalendarOptions: [(title: String, options: [CalendarOption])] {
        let grouped = Dictionary(grouping: calendarOptions, by: \.section)
        let order = ["iCloud", "Google", "Other", "Birthdays", "Subscribed calendars"]
        return grouped
            .map { key, value in
                (title: key, options: value.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
            }
            .sorted { lhs, rhs in
                let left = order.firstIndex(of: lhs.title) ?? Int.max
                let right = order.firstIndex(of: rhs.title) ?? Int.max
                if left != right {
                    return left < right
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var calendarOptions: [CalendarOption] {
        var options: [CalendarOption] = []

        if selectedProviders.contains(.apple) {
            options.append(contentsOf: appleCalendars.map { calendar in
                CalendarOption(
                    id: "apple:\(calendar.id)",
                    title: calendar.title,
                    section: appleSectionName(for: calendar.sourceTitle),
                    provider: .apple,
                    rawCalendarID: calendar.id
                )
            })
        }

        if selectedProviders.contains(.google) {
            options.append(
                CalendarOption(
                    id: "google:primary",
                    title: "Primary",
                    section: "Google",
                    provider: .google,
                    rawCalendarID: "primary"
                )
            )
        }

        return options
    }

    var body: some View {
        ZStack {
            stepView
                .id(stepID)
                .transition(isForward ? .onboardingForward : .onboardingBackward)
        }
        .animation(OnboardingMotion.easing, value: stepID)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .goals:
            OnboardingShellView(
                progress: progressValue,
                title: "What do you want help with right now?",
                subtitle: "Pick the outcomes you want Synapse to optimize first.",
                showsBack: false,
                onBack: {},
                onSkip: {
                    navigateToNextStep()
                },
                onPrimary: {
                    navigateToNextStep()
                }
            ) {
                goalCards
            }

        case .notifications:
            OnboardingShellView(
                progress: progressValue,
                title: "Stay gently on track",
                subtitle: "Enable reminders only if you want them. You can change this later.",
                onBack: {
                    navigateToPreviousStep()
                },
                onSkip: {
                    applyNotificationsChoice(.disabled)
                    navigateToNextStep()
                },
                onPrimary: {
                    navigateToNextStep()
                }
            ) {
                notificationsCards
            }

        case .calendarIntro:
            OnboardingShellView(
                progress: progressValue,
                title: "Import your calendar for a quick start",
                subtitle: "Bring in Apple or Google events as read-only appointments.",
                onBack: {
                    navigateToPreviousStep()
                },
                onSkip: {
                    skipCalendarSetup()
                },
                onPrimary: {
                    if selectedProviders.isEmpty {
                        skipCalendarSetup()
                    } else {
                        jump(to: .calendarSelect, forward: true)
                    }
                }
            ) {
                calendarIntroContent
            }

        case .calendarSelect:
            OnboardingShellView(
                progress: progressValue,
                title: "Choose calendars",
                subtitle: "Select what should appear in Today. Sync remains read-only.",
                onBack: {
                    navigateToPreviousStep()
                },
                onSkip: {
                    navigateToNextStep()
                },
                onPrimary: {
                    navigateToNextStep()
                }
            ) {
                calendarSelectionContent
            }
            .onAppear {
                if selectedProviders.contains(.apple) {
                    loadAppleCalendarsIfNeeded()
                }
            }

        case .routineTimeBlocks:
            OnboardingShellView(
                progress: progressValue,
                title: "When do your habits matter most?",
                subtitle: "Choose the time blocks where you want identity support.",
                onBack: {
                    navigateToPreviousStep()
                },
                onSkip: {
                    selectedTimeBlocks = []
                    navigateToNextStep()
                },
                onPrimary: {
                    navigateToNextStep()
                }
            ) {
                timeBlockContent
            }

        case let .routinePicker(block):
            OnboardingShellView(
                progress: progressValue,
                title: "Pick your \(block.title.lowercased()) habits",
                subtitle: "Choose presets now. You can reorder or edit them later.",
                onBack: {
                    navigateToPreviousStep()
                },
                onSkip: {
                    navigateToNextStep()
                },
                onPrimary: {
                    navigateToNextStep()
                }
            ) {
                routinePickerContent(for: block)
            }

        case .finish:
            OnboardingShellView(
                progress: progressValue,
                title: "Ready to start",
                subtitle: "Your identity setup is in place. You can adjust everything in Settings.",
                primaryTitle: isPersisting ? "Preparing..." : "Start My Day",
                isPrimaryDisabled: isPersisting,
                showsSkip: false,
                onBack: {
                    navigateToPreviousStep()
                },
                onSkip: {},
                onPrimary: {
                    completeOnboarding()
                }
            ) {
                finishContent
            }
        }
    }

    private var goalCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
            ForEach(OnboardingGoal.allCases) { goal in
                let isSelected = selectedGoals.contains(goal)
                Button {
                    toggleGoal(goal)
                } label: {
                    Text(goal.title)
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.cardInset)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .fill(isSelected ? Theme.surface : Theme.surface2.opacity(0.85))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .stroke(isSelected ? Theme.accent.opacity(0.6) : Theme.textSecondary.opacity(0.16), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notificationsCards: some View {
        VStack(spacing: Theme.Spacing.xs) {
            notificationChoiceCard(
                title: "Yes, send reminders",
                subtitle: "We will ask for system permission now.",
                isSelected: notificationsEnabled,
                action: {
                    requestNotificationPermissionAndApply()
                }
            )

            notificationChoiceCard(
                title: "No thanks",
                subtitle: "You can enable reminders later in Settings.",
                isSelected: !notificationsEnabled,
                action: {
                    applyNotificationsChoice(.disabled)
                }
            )
        }
    }

    private var calendarIntroContent: some View {
        VStack(spacing: Theme.Spacing.xs) {
            providerButton(title: "Connect Apple Calendar", provider: .apple)
            providerButton(title: "Connect Google Calendar", provider: .google)

            Button {
                skipCalendarSetup()
            } label: {
                Text("Not now")
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(Theme.surface2.opacity(0.9))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .stroke(Theme.textSecondary.opacity(0.16), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var calendarSelectionContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if selectedProviders.isEmpty {
                Text("No provider selected. You can configure calendar sync in Settings later.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(Theme.Spacing.cardInset)
                    .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
            } else {
                if selectedProviders.contains(.apple) && appleCalendars.isEmpty {
                    ProgressView("Loading Apple calendars...")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                }

                ForEach(groupedCalendarOptions, id: \.title) { group in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(group.title)
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)

                        VStack(spacing: Theme.Spacing.xxs) {
                            ForEach(group.options) { option in
                                Button {
                                    toggleCalendarSelection(option)
                                } label: {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: selectedCalendarIDs.contains(option.id) ? "checkmark.circle.fill" : "circle")
                                            .font(Theme.Typography.iconCompact)
                                            .foregroundStyle(selectedCalendarIDs.contains(option.id) ? Theme.accent : Theme.textSecondary)

                                        Text(option.title)
                                            .font(Theme.Typography.bodySmallStrong)
                                            .foregroundStyle(Theme.text)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, Theme.Spacing.xs)
                                    .padding(.vertical, Theme.Spacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Theme.surface2.opacity(0.85))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var timeBlockContent: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(HabitTimeBlock.allCases) { block in
                let selected = selectedTimeBlocks.contains(block)
                Button {
                    toggleTimeBlock(block)
                } label: {
                    HStack {
                        Text(block.title)
                            .font(Theme.Typography.bodySmallStrong)
                            .foregroundStyle(selected ? Theme.text : Theme.textSecondary)

                        Spacer(minLength: 0)

                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(Theme.Typography.iconCompact)
                            .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                    }
                    .padding(Theme.Spacing.cardInset)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(selected ? Theme.surface : Theme.surface2.opacity(0.86))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .stroke(selected ? Theme.accent.opacity(0.58) : Theme.textSecondary.opacity(0.16), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func routinePickerContent(for block: HabitTimeBlock) -> some View {
        let options = habitPresetOptions(for: block)
        let selected = selectedHabitTemplates[block, default: []]
        let customSelections = selected
            .filter { !options.contains($0) }
            .sorted()
        let customInputVisible = showingCustomHabitInputForBlocks.contains(block)
        let customDraft = customHabitDraftByBlock[block, default: ""]

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Theme.Spacing.xs)], spacing: Theme.Spacing.xs) {
                ForEach(options, id: \.self) { template in
                    let isSelected = selected.contains(template)
                    Button {
                        toggleHabitTemplate(template, for: block)
                    } label: {
                        Text(template)
                            .font(Theme.Typography.bodySmallStrong)
                            .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Spacing.cardInset)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .fill(isSelected ? Theme.surface : Theme.surface2.opacity(0.86))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .stroke(isSelected ? Theme.accent.opacity(0.58) : Theme.textSecondary.opacity(0.16), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showingCustomHabitInputForBlocks.insert(block)
                } label: {
                    Text("Something else")
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.cardInset)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .fill(Theme.surface2.opacity(0.86))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .stroke(Theme.textSecondary.opacity(0.16), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }

            if customInputVisible {
                HStack(spacing: Theme.Spacing.xs) {
                    TextField(
                        "Type a custom habit",
                        text: Binding(
                            get: { customHabitDraftByBlock[block, default: ""] },
                            set: { customHabitDraftByBlock[block] = $0 }
                        )
                    )
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)

                    Button {
                        addCustomHabit(for: block)
                    } label: {
                        Text("Add")
                            .font(Theme.Typography.bodySmallStrong)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Theme.text)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(customDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(customDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }

            if !customSelections.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Custom")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)

                    ForEach(customSelections, id: \.self) { custom in
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(custom)
                                .font(Theme.Typography.bodySmallStrong)
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Button {
                                removeCustomHabit(custom, for: block)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(Theme.Typography.iconCompact)
                                    .foregroundStyle(Theme.textSecondary.opacity(0.78))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.surface2.opacity(0.86))
                        )
                    }
                }
            }

            Text("Selected \(selected.count) presets")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var finishContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            summaryRow(label: "Goals", value: selectedGoals.isEmpty ? "None" : "\(selectedGoals.count)")
            summaryRow(label: "Reminders", value: notificationsEnabled ? "Enabled" : "Off")
            summaryRow(label: "Calendar", value: calendarState == .connected ? "Connected" : "Skipped")
            summaryRow(label: "Time blocks", value: selectedTimeBlocks.isEmpty ? "None" : "\(selectedTimeBlocks.count)")

            Text("You can adjust calendar sync, reminders, habits, and task views anytime in Settings.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            Text(value)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
        }
    }

    private func notificationChoiceCard(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text(title)
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)

                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.cardInset)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isSelected ? Theme.surface : Theme.surface2.opacity(0.86))
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .stroke(isSelected ? Theme.accent.opacity(0.58) : Theme.textSecondary.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func providerButton(title: String, provider: CalendarProviderChoice) -> some View {
        let selected = selectedProviders.contains(provider)

        return Button {
            connectProvider(provider)
        } label: {
            HStack {
                Text(title)
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(selected ? Theme.text : .white)

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Typography.iconCompact)
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(selected ? Theme.surface2 : Theme.text)
            )
        }
        .buttonStyle(.plain)
    }

    private func connectProvider(_ provider: CalendarProviderChoice) {
        selectedProviders.insert(provider)
        calendarState = .connected

        if provider == .apple {
            loadAppleCalendarsIfNeeded()
        }

        if provider == .google, !selectedCalendarIDs.contains("google:primary") {
            selectedCalendarIDs.insert("google:primary")
        }

        jump(to: .calendarSelect, forward: true)
    }

    private func appleSectionName(for sourceTitle: String) -> String {
        let normalized = sourceTitle.lowercased()

        if normalized.contains("icloud") {
            return "iCloud"
        }

        if normalized.contains("google") || normalized.contains("gmail") {
            return "Google"
        }

        if normalized.contains("birthday") {
            return "Birthdays"
        }

        if normalized.contains("subscribed") {
            return "Subscribed calendars"
        }

        return "Other"
    }

    private func toggleGoal(_ goal: OnboardingGoal) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }

    private func toggleTimeBlock(_ block: HabitTimeBlock) {
        if selectedTimeBlocks.contains(block) {
            selectedTimeBlocks.remove(block)
            selectedHabitTemplates[block] = nil
        } else {
            selectedTimeBlocks.insert(block)
        }
    }

    private func toggleHabitTemplate(_ template: String, for block: HabitTimeBlock) {
        var selected = selectedHabitTemplates[block, default: []]
        if selected.contains(template) {
            selected.remove(template)
        } else {
            selected.insert(template)
        }
        selectedHabitTemplates[block] = selected
    }

    private func toggleCalendarSelection(_ option: CalendarOption) {
        if selectedCalendarIDs.contains(option.id) {
            selectedCalendarIDs.remove(option.id)
        } else {
            selectedCalendarIDs.insert(option.id)
        }
    }

    private func navigateToNextStep() {
        let steps = flowSteps
        guard let index = steps.firstIndex(of: step) else { return }
        guard index + 1 < steps.count else {
            completeOnboarding()
            return
        }
        jump(to: steps[index + 1], forward: true)
    }

    private func navigateToPreviousStep() {
        let steps = flowSteps
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        jump(to: steps[index - 1], forward: false)
    }

    private func jump(to destination: OnboardingStep, forward: Bool) {
        isForward = forward
        withAnimation(OnboardingMotion.easing) {
            step = destination
        }
    }

    private func skipCalendarSetup() {
        calendarState = .skipped
        selectedProviders = []
        selectedCalendarIDs = []
        jump(to: .routineTimeBlocks, forward: true)
    }

    private func applyNotificationsChoice(_ choice: NotificationChoice) {
        notificationsEnabled = choice == .enabled
    }

    private func requestNotificationPermissionAndApply() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                applyNotificationsChoice(granted ? .enabled : .disabled)
            }
        }
    }

    private func completeOnboarding() {
        guard !isPersisting else { return }
        isPersisting = true

        persistPreferences()
        seedHabitsFromOnboarding()

        do {
            try modelContext.save()
        } catch {
            print("Onboarding save error: \(error)")
        }

        onCompleted()
    }

    private func persistPreferences() {
        let preferences = preferenceRecords.first ?? {
            let created = UserPreferences()
            modelContext.insert(created)
            return created
        }()

        preferences.goals = selectedGoals
        preferences.notificationsEnabled = notificationsEnabled
        preferences.enabledTimeBlocks = selectedTimeBlocks
        preferences.calendarIntegrationState = calendarState
        preferences.connectedProviders = selectedProviders
        preferences.selectedCalendarIDs = selectedCalendarIDs
        preferences.calendarIntegrationMode = .readOnly
        preferences.hasCompletedOnboarding = true
        preferences.touch()

        let syncSettings = syncSettingsRecords.first ?? {
            let created = CalendarSyncSettings()
            modelContext.insert(created)
            return created
        }()

        syncSettings.appleSyncEnabled = selectedProviders.contains(.apple)

        let selectedAppleCalendarIDs = selectedCalendarIDs
            .filter { $0.hasPrefix("apple:") }
            .map { String($0.dropFirst("apple:".count)) }

        let selectedAppleCalendarIDSet = Set(selectedAppleCalendarIDs)
        syncSettings.appleCalendarIDs = selectedAppleCalendarIDSet

        let birthdayAppleIDs = Set(
            appleCalendars
                .filter(isBirthdayAppleCalendar)
                .map(\.id)
        )
        syncSettings.includeBirthdays =
            syncSettings.appleSyncEnabled
            && !birthdayAppleIDs.isDisjoint(with: selectedAppleCalendarIDSet)

        syncSettings.googleSyncEnabled = selectedProviders.contains(.google)

        let selectedGoogleCalendarID = selectedCalendarIDs
            .first { $0.hasPrefix("google:") }
            .map { String($0.dropFirst("google:".count)) }

        if syncSettings.googleSyncEnabled {
            syncSettings.googleCalendarID = selectedGoogleCalendarID ?? syncSettings.googleCalendarID ?? "primary"
        } else {
            syncSettings.googleCalendarID = nil
        }

        syncSettings.touch()
    }

    private func seedHabitsFromOnboarding() {
        let existingKeys = Set(habits.map { habit in
            habitIdentityKey(title: habit.title, partOfDay: habit.timeOfDay)
        })

        var mutableExistingKeys = existingKeys
        var nextSortOrder = (habits.map(\.sortOrder).max() ?? -1) + 1

        for block in orderedTimeBlocks {
            let templates = selectedHabitTemplates[block, default: []]
            for template in templates.sorted() {
                let key = habitIdentityKey(title: template, partOfDay: block.partOfDay)
                guard !mutableExistingKeys.contains(key) else { continue }

                let created = Habit(
                    title: template,
                    frequency: .daily,
                    timeOfDay: block.partOfDay,
                    scheduledWeekdays: [],
                    sortOrder: nextSortOrder
                )

                nextSortOrder += 1
                modelContext.insert(created)
                mutableExistingKeys.insert(key)
            }
        }
    }

    private func habitIdentityKey(title: String, partOfDay: TaskPartOfDay) -> String {
        "\(title.lowercased())::\(partOfDay.rawValue)"
    }

    private func habitPresetOptions(for block: HabitTimeBlock) -> [String] {
        switch block {
        case .morning:
            return [
                "Hydrate",
                "Morning plan",
                "Sunlight walk",
                "Read 10 min",
                "Light stretch"
            ]
        case .afternoon:
            return [
                "Midday reset",
                "Protein lunch",
                "Inbox sweep",
                "Walk break",
                "Deep work block"
            ]
        case .evening:
            return [
                "Reflect",
                "Prepare tomorrow",
                "No-screen wind down",
                "Evening stretch",
                "Gratitude journal"
            ]
        }
    }

    private func loadAppleCalendarsIfNeeded() {
        guard !didLoadAppleCalendars else { return }
        didLoadAppleCalendars = true

        Task {
            let calendars = await appointmentSyncService.availableAppleCalendars()
            await MainActor.run {
                appleCalendars = calendars

                let hasAppleSelection = selectedCalendarIDs.contains { $0.hasPrefix("apple:") }
                if !hasAppleSelection {
                    for calendar in calendars {
                        selectedCalendarIDs.insert("apple:\(calendar.id)")
                    }
                }
            }
        }
    }

    private func progress(slot: Int, totalSlots: Int) -> Double {
        let clamped = min(max(slot, 1), totalSlots)
        return Double(clamped) / Double(totalSlots)
    }

    private func addCustomHabit(for block: HabitTimeBlock) {
        let trimmed = customHabitDraftByBlock[block, default: ""]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var selected = selectedHabitTemplates[block, default: []]
        let duplicate = selected.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        guard !duplicate else {
            customHabitDraftByBlock[block] = ""
            return
        }

        selected.insert(trimmed)
        selectedHabitTemplates[block] = selected
        customHabitDraftByBlock[block] = ""
    }

    private func removeCustomHabit(_ customHabit: String, for block: HabitTimeBlock) {
        var selected = selectedHabitTemplates[block, default: []]
        selected.remove(customHabit)
        selectedHabitTemplates[block] = selected
    }

    private func isBirthdayAppleCalendar(_ calendar: AvailableAppleCalendar) -> Bool {
        let normalizedTitle = calendar.title.lowercased()
        let normalizedSource = calendar.sourceTitle.lowercased()
        return normalizedTitle.contains("birthday") || normalizedSource.contains("birthday")
    }

    private var stepID: String {
        switch step {
        case .goals:
            return "goals"
        case .notifications:
            return "notifications"
        case .calendarIntro:
            return "calendarIntro"
        case .calendarSelect:
            return "calendarSelect"
        case .routineTimeBlocks:
            return "routineTimeBlocks"
        case let .routinePicker(block):
            return "routinePicker-\(block.rawValue)"
        case .finish:
            return "finish"
        }
    }
}
