import SwiftData
import SwiftUI

struct CalendarSyncSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var settings: CalendarSyncSettings
    @ObservedObject var syncService: AppointmentSyncService
    let onDidSync: (() -> Void)?

    @State private var appleCalendars: [AvailableAppleCalendar] = []
    @State private var hasLoadedAppleCalendars = false

    init(
        settings: CalendarSyncSettings,
        syncService: AppointmentSyncService,
        onDidSync: (() -> Void)? = nil
    ) {
        self.settings = settings
        self.syncService = syncService
        self.onDidSync = onDidSync
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        appleCard
                        googleCard
                        syncActionCard
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Calendar Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        persistSettings()
                        dismiss()
                    }
                    .tint(Theme.accent)
                }
            }
            .onAppear {
                if settings.appleSyncEnabled {
                    loadAppleCalendarsIfNeeded()
                }
            }
            .onChange(of: settings.appleSyncEnabled) { _, isEnabled in
                persistSettings()
                if isEnabled {
                    loadAppleCalendarsIfNeeded()
                }
            }
            .onChange(of: settings.googleSyncEnabled) { _, _ in
                persistSettings()
            }
            .onDisappear {
                persistSettings()
            }
        }
    }

    private var appleCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Toggle("Apple Calendar", isOn: $settings.appleSyncEnabled)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
                .tint(Theme.accent)

            Text("Bring in Apple Calendar events as appointments.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            if settings.appleSyncEnabled {
                Button {
                    loadAppleCalendars(force: true)
                } label: {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: "arrow.clockwise")
                            .font(Theme.Typography.caption)
                        Text(hasLoadedAppleCalendars ? "Reload calendars" : "Load calendars")
                            .font(Theme.Typography.bodySmallStrong)
                    }
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)

                if hasLoadedAppleCalendars {
                    if appleCalendars.isEmpty {
                        Text("No Apple calendars are currently available.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        VStack(spacing: Theme.Spacing.xxs) {
                            ForEach(appleCalendars) { calendar in
                                appleCalendarRow(calendar)
                            }
                        }

                        Text("Selected \(settings.appleCalendarIDs.count) of \(appleCalendars.count).")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary.opacity(0.82))
                    }
                }

                if let date = settings.lastAppleSyncAt {
                    Text("Last Apple sync: \(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.82))
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private func appleCalendarRow(_ calendar: AvailableAppleCalendar) -> some View {
        let isSelected = settings.appleCalendarIDs.contains(calendar.id)

        return Button {
            var selected = settings.appleCalendarIDs
            if isSelected {
                selected.remove(calendar.id)
            } else {
                selected.insert(calendar.id)
            }
            settings.appleCalendarIDs = selected
            persistSettings()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text(calendar.title)
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)

                    Text(calendar.sourceTitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface2.opacity(0.7))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.textSecondary.opacity(0.12), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private var googleCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Toggle("Google Calendar", isOn: $settings.googleSyncEnabled)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
                .tint(Theme.accent)

            Text("Use a Google Calendar API access token.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            if settings.googleSyncEnabled {
                TextField("Calendar ID", text: googleCalendarIDBinding)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.text)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)

                SecureField("Access token", text: googleAccessTokenBinding)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.text)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)

                Text("Generate an OAuth token with Google Calendar read access and paste it here.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.82))

                if let date = settings.lastGoogleSyncAt {
                    Text("Last Google sync: \(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.82))
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var syncActionCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                syncNow()
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    if syncService.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(Theme.Typography.iconCompact)
                    }

                    Text(syncService.isSyncing ? "Syncing..." : "Sync now")
                        .font(Theme.Typography.bodySmallStrong)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.accent, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(syncService.isSyncing || !canSync)

            if !canSync {
                Text("Enable Apple and/or Google sync to run imports.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if let error = syncService.lastErrorMessage {
                Text(error)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else if let summary = syncService.lastSummary {
                Text(summaryLine(for: summary))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var canSync: Bool {
        if settings.appleSyncEnabled {
            return true
        }

        if settings.googleSyncEnabled {
            return settings.googleCalendarID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && settings.googleAccessToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }

        return false
    }

    private var googleCalendarIDBinding: Binding<String> {
        Binding(
            get: { settings.googleCalendarID ?? "" },
            set: {
                settings.googleCalendarID = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
                persistSettings()
            }
        )
    }

    private var googleAccessTokenBinding: Binding<String> {
        Binding(
            get: { settings.googleAccessToken ?? "" },
            set: {
                settings.googleAccessToken = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
                persistSettings()
            }
        )
    }

    private func summaryLine(for summary: AppointmentSyncSummary) -> String {
        "Imported \(summary.totalImported) appointments (Apple \(summary.appleImported), Google \(summary.googleImported))."
    }

    private func loadAppleCalendarsIfNeeded() {
        guard !hasLoadedAppleCalendars else { return }
        loadAppleCalendars(force: false)
    }

    private func loadAppleCalendars(force: Bool) {
        if force {
            hasLoadedAppleCalendars = false
        }

        Task {
            let calendars = await syncService.availableAppleCalendars()
            appleCalendars = calendars
            hasLoadedAppleCalendars = true

            let availableIDs = Set(calendars.map(\.id))
            var selectedIDs = settings.appleCalendarIDs.intersection(availableIDs)
            if selectedIDs.isEmpty {
                selectedIDs = availableIDs
            }

            settings.appleCalendarIDs = selectedIDs
            persistSettings()
        }
    }

    private func syncNow() {
        persistSettings()

        Task {
            _ = await syncService.syncNow(using: settings, in: modelContext)
            onDidSync?()
        }
    }

    private func persistSettings() {
        settings.touch()
        try? modelContext.save()
    }
}
