import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var session: AppSession

    @Query(sort: [SortDescriptor(\CalendarSyncSettings.createdAt, order: .forward)])
    private var syncSettingsRecords: [CalendarSyncSettings]

    @Query(sort: [SortDescriptor(\UserPreferences.createdAt, order: .forward)])
    private var preferenceRecords: [UserPreferences]

    @StateObject private var syncService = AppointmentSyncService()

    @State private var resolvedSyncSettings: CalendarSyncSettings?
    @State private var resolvedPreferences: UserPreferences?

    @State private var showingCalendarSync = false
    @State private var showingManageHabits = false
    @State private var showingAllTasks = false
    @State private var showingTimeBlockEditor = false

    @State private var remindersEnabled = false
    @State private var didLoadReminderState = false

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        calendarSection
                        notificationsSection
                        habitSection
                        taskSection
                        accountSection
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
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
            .sheet(isPresented: $showingCalendarSync) {
                if let settings = resolvedSyncSettings {
                    CalendarSyncSheet(
                        settings: settings,
                        syncService: syncService,
                        onDidSync: nil
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                } else {
                    ProgressView()
                }
            }
            .sheet(isPresented: $showingManageHabits) {
                ManageHabitsView(title: "Habits")
            }
            .sheet(isPresented: $showingAllTasks) {
                AllTasksView()
            }
            .sheet(isPresented: $showingTimeBlockEditor) {
                if let preferences = resolvedPreferences {
                    TimeBlockEditorSheet(preferences: preferences)
                } else {
                    ProgressView()
                }
            }
            .onAppear {
                ensureRecordsExist()

                if !didLoadReminderState {
                    remindersEnabled = resolvedPreferences?.notificationsEnabled ?? false
                    didLoadReminderState = true
                }
            }
            .onChange(of: remindersEnabled) { _, enabled in
                guard didLoadReminderState else { return }
                if enabled {
                    requestNotificationPermission()
                } else {
                    resolvedPreferences?.notificationsEnabled = false
                    resolvedPreferences?.touch()
                    try? modelContext.save()
                }
            }
        }
    }

    private var calendarSection: some View {
        settingsCard(title: "Calendar") {
            settingsActionRow(title: "Connect Apple") {
                ensureRecordsExist()
                resolvedSyncSettings?.appleSyncEnabled = true
                resolvedSyncSettings?.touch()
                try? modelContext.save()
                showingCalendarSync = true
            }

            settingsActionRow(title: "Connect Google") {
                ensureRecordsExist()
                resolvedSyncSettings?.googleSyncEnabled = true
                resolvedSyncSettings?.touch()
                try? modelContext.save()
                showingCalendarSync = true
            }

            settingsActionRow(title: "Choose calendars") {
                ensureRecordsExist()
                showingCalendarSync = true
            }

            settingsActionRow(title: syncService.isSyncing ? "Refreshing..." : "Refresh") {
                ensureRecordsExist()
                guard let settings = resolvedSyncSettings else { return }
                Task {
                    _ = await syncService.syncNow(using: settings, in: modelContext)
                }
            }

            Toggle("Include birthdays", isOn: Binding(
                get: { resolvedSyncSettings?.includeBirthdays ?? true },
                set: { newValue in
                    ensureRecordsExist()
                    resolvedSyncSettings?.includeBirthdays = newValue
                    resolvedSyncSettings?.touch()
                    try? modelContext.save()
                }
            ))
            .font(Theme.Typography.bodySmallStrong)
            .foregroundStyle(Theme.text)
            .tint(Theme.accent)
        }
    }

    private var notificationsSection: some View {
        settingsCard(title: "Notifications") {
            Toggle("Enable reminders", isOn: $remindersEnabled)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
                .tint(Theme.accent)

            settingsActionRow(title: "Reminder settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
    }

    private var habitSection: some View {
        settingsCard(title: "Habits") {
            settingsActionRow(title: "Manage time blocks") {
                ensureRecordsExist()
                showingTimeBlockEditor = true
            }

            settingsActionRow(title: "Edit habits") {
                showingManageHabits = true
            }
        }
    }

    private var taskSection: some View {
        settingsCard(title: "Tasks") {
            settingsActionRow(title: "Open all tasks") {
                showingAllTasks = true
            }
        }
    }

    private var accountSection: some View {
        settingsCard(title: "Account") {
            settingsActionRow(title: "Run onboarding again") {
                session.restartOnboarding()
                dismiss()
            }

            settingsActionRow(title: "Sign out", role: .destructive) {
                session.signOut()
                dismiss()
            }
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            content()
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private func settingsActionRow(title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role) {
            action()
        } label: {
            HStack {
                Text(title)
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(role == .destructive ? Color.red : Theme.text)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.72))
            }
            .padding(.vertical, Theme.Spacing.xxxs)
        }
        .buttonStyle(.plain)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                remindersEnabled = granted
                ensureRecordsExist()
                resolvedPreferences?.notificationsEnabled = granted
                resolvedPreferences?.touch()
                try? modelContext.save()
            }
        }
    }

    private func ensureRecordsExist() {
        if resolvedSyncSettings == nil {
            if let existing = syncSettingsRecords.first {
                resolvedSyncSettings = existing
            } else {
                let created = CalendarSyncSettings()
                modelContext.insert(created)
                resolvedSyncSettings = created
            }
        }

        if resolvedPreferences == nil {
            if let existing = preferenceRecords.first {
                resolvedPreferences = existing
            } else {
                let created = UserPreferences()
                modelContext.insert(created)
                resolvedPreferences = created
            }
        }

        try? modelContext.save()
    }
}

private struct TimeBlockEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var preferences: UserPreferences

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(HabitTimeBlock.allCases) { block in
                        let isSelected = preferences.enabledTimeBlocks.contains(block)
                        Button {
                            var selected = preferences.enabledTimeBlocks
                            if isSelected {
                                selected.remove(block)
                            } else {
                                selected.insert(block)
                            }
                            preferences.enabledTimeBlocks = selected
                        } label: {
                            HStack {
                                Text(block.title)
                                    .font(Theme.Typography.bodySmallStrong)
                                    .foregroundStyle(Theme.text)

                                Spacer(minLength: 0)

                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(Theme.Typography.iconCompact)
                                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                            }
                            .padding(Theme.Spacing.cardInset)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .fill(Theme.surface2)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.md)
                .padding(.top, Theme.Spacing.lg)
            }
            .navigationTitle("Time Blocks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        preferences.touch()
                        try? modelContext.save()
                        dismiss()
                    }
                    .tint(Theme.accent)
                }
            }
        }
    }
}
