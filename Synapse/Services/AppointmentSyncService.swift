import Combine
import EventKit
import Foundation
import SwiftData

struct AvailableAppleCalendar: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String
}

struct AppointmentSyncSummary {
    var appleImported: Int = 0
    var googleImported: Int = 0
    var removed: Int = 0

    var totalImported: Int {
        appleImported + googleImported
    }
}

enum AppointmentSyncError: LocalizedError {
    case appleAccessDenied
    case googleCredentialsMissing
    case invalidGoogleRequest
    case googleHTTPStatus(Int, String?)
    case googleDecodeFailure

    var errorDescription: String? {
        switch self {
        case .appleAccessDenied:
            return "Calendar permission is needed to sync Apple appointments."
        case .googleCredentialsMissing:
            return "Add a Google calendar ID and access token to sync Google appointments."
        case .invalidGoogleRequest:
            return "Could not build the Google Calendar request."
        case let .googleHTTPStatus(code, message):
            if let message, !message.isEmpty {
                return "Google Calendar returned \(code): \(message)"
            }
            return "Google Calendar returned \(code)."
        case .googleDecodeFailure:
            return "Could not read the Google Calendar response."
        }
    }
}

@MainActor
final class AppointmentSyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastSummary: AppointmentSyncSummary?

    private let eventStore = EKEventStore()
    private let session: URLSession

    private let googleDateTimeFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let googleDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let googleSyncWindowDaysBefore = 30
    private let googleSyncWindowDaysAfter = 180

    init(session: URLSession = .shared) {
        self.session = session
    }

    func ensureSettings(in modelContext: ModelContext) -> CalendarSyncSettings {
        let descriptor = FetchDescriptor<CalendarSyncSettings>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let settings = CalendarSyncSettings()
        modelContext.insert(settings)
        try? modelContext.save()
        return settings
    }

    func availableAppleCalendars() async -> [AvailableAppleCalendar] {
        let granted = await requestAppleCalendarAccessIfNeeded()
        guard granted else {
            lastErrorMessage = AppointmentSyncError.appleAccessDenied.errorDescription
            return []
        }

        let calendars = eventStore.calendars(for: .event)
            .map {
                AvailableAppleCalendar(
                    id: $0.calendarIdentifier,
                    title: $0.title,
                    sourceTitle: $0.source.title
                )
            }
            .sorted { lhs, rhs in
                if lhs.sourceTitle != rhs.sourceTitle {
                    return lhs.sourceTitle.localizedCaseInsensitiveCompare(rhs.sourceTitle) == .orderedAscending
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        return calendars
    }

    func syncNow(using settings: CalendarSyncSettings, in modelContext: ModelContext) async -> AppointmentSyncSummary {
        guard !isSyncing else {
            return lastSummary ?? AppointmentSyncSummary()
        }

        isSyncing = true
        defer { isSyncing = false }
        lastErrorMessage = nil

        var errors: [String] = []
        var summary = AppointmentSyncSummary()
        var allAppointments = (try? modelContext.fetch(FetchDescriptor<Appointment>())) ?? []
        let window = syncWindow()

        if settings.appleSyncEnabled {
            do {
                let result = try await syncAppleAppointments(
                    settings: settings,
                    window: window,
                    allAppointments: &allAppointments,
                    modelContext: modelContext
                )
                settings.lastAppleSyncAt = .now
                summary.appleImported = result.imported
                summary.removed += result.removed
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        if settings.googleSyncEnabled {
            do {
                let result = try await syncGoogleAppointments(
                    settings: settings,
                    window: window,
                    allAppointments: &allAppointments,
                    modelContext: modelContext
                )
                settings.lastGoogleSyncAt = .now
                summary.googleImported = result.imported
                summary.removed += result.removed
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        settings.touch()

        do {
            try modelContext.save()
        } catch {
            errors.append("Could not save synced appointments.")
        }

        if errors.isEmpty {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = errors.joined(separator: "\n")
        }

        lastSummary = summary
        return summary
    }

    private func syncWindow(now: Date = .now) -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -googleSyncWindowDaysBefore, to: now) ?? now.addingTimeInterval(-2_592_000)
        let end = calendar.date(byAdding: .day, value: googleSyncWindowDaysAfter, to: now) ?? now.addingTimeInterval(15_552_000)
        return DateInterval(start: start, end: end)
    }

    private struct SourceSyncResult {
        var imported: Int
        var removed: Int
    }

    private func syncAppleAppointments(
        settings: CalendarSyncSettings,
        window: DateInterval,
        allAppointments: inout [Appointment],
        modelContext: ModelContext
    ) async throws -> SourceSyncResult {
        let granted = await requestAppleCalendarAccessIfNeeded()
        guard granted else {
            throw AppointmentSyncError.appleAccessDenied
        }

        let availableCalendars = eventStore.calendars(for: .event)
        let selectedIDs = settings.appleCalendarIDs
        let selectedCalendars = selectedIDs.isEmpty
            ? availableCalendars
            : availableCalendars.filter { selectedIDs.contains($0.calendarIdentifier) }

        let targetCalendars = settings.includeBirthdays
            ? selectedCalendars
            : selectedCalendars.filter { calendar in
                let title = calendar.title.lowercased()
                let source = calendar.source.title.lowercased()
                return !title.contains("birthday") && !source.contains("birthday")
            }

        guard !targetCalendars.isEmpty else {
            return SourceSyncResult(imported: 0, removed: 0)
        }

        let predicate = eventStore.predicateForEvents(
            withStart: window.start,
            end: window.end,
            calendars: targetCalendars
        )

        let events = eventStore.events(matching: predicate)
        var existingByExternalID = Dictionary(
            uniqueKeysWithValues: allAppointments.compactMap { appointment -> (String, Appointment)? in
                guard appointment.source == .appleCalendar,
                      let externalID = appointment.externalID,
                      !externalID.isEmpty else {
                    return nil
                }
                return (externalID, appointment)
            }
        )

        var seenExternalIDs: Set<String> = []
        for event in events {
            let externalID = appleExternalID(for: event)
            guard !externalID.isEmpty else { continue }

            let appointment = existingByExternalID[externalID] ?? {
                let created = Appointment(
                    title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled appointment",
                    startDate: event.startDate,
                    endDate: nil,
                    isAllDay: event.isAllDay,
                    source: .appleCalendar,
                    externalID: externalID,
                    calendarID: event.calendar.calendarIdentifier
                )
                modelContext.insert(created)
                allAppointments.append(created)
                existingByExternalID[externalID] = created
                return created
            }()

            appointment.title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled appointment"
            appointment.startDate = event.startDate
            appointment.endDate = normalizedEndDate(start: event.startDate, end: event.endDate)
            appointment.isAllDay = event.isAllDay
            appointment.location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            appointment.notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            appointment.source = .appleCalendar
            appointment.externalID = externalID
            appointment.calendarID = event.calendar.calendarIdentifier

            seenExternalIDs.insert(externalID)
        }

        let removed = removeStaleSyncedAppointments(
            source: .appleCalendar,
            allowedCalendarIDs: Set(targetCalendars.map(\.calendarIdentifier)),
            keepExternalIDs: seenExternalIDs,
            window: window,
            allAppointments: &allAppointments,
            modelContext: modelContext
        )

        return SourceSyncResult(imported: seenExternalIDs.count, removed: removed)
    }

    private func syncGoogleAppointments(
        settings: CalendarSyncSettings,
        window: DateInterval,
        allAppointments: inout [Appointment],
        modelContext: ModelContext
    ) async throws -> SourceSyncResult {
        let calendarID = settings.googleCalendarID?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let accessToken = settings.googleAccessToken?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty

        guard let calendarID, let accessToken else {
            throw AppointmentSyncError.googleCredentialsMissing
        }

        var seenExternalIDs: Set<String> = []
        var existingByExternalID = Dictionary(
            uniqueKeysWithValues: allAppointments.compactMap { appointment -> (String, Appointment)? in
                guard appointment.source == .googleCalendar,
                      let externalID = appointment.externalID,
                      !externalID.isEmpty else {
                    return nil
                }
                return (externalID, appointment)
            }
        )

        var pageToken: String?

        repeat {
            let page = try await fetchGoogleEventsPage(
                calendarID: calendarID,
                accessToken: accessToken,
                window: window,
                pageToken: pageToken
            )

            for event in page.items where event.status?.lowercased() != "cancelled" {
                guard let startDate = decodeGoogleDate(event.start) else { continue }
                let externalID = event.id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !externalID.isEmpty else { continue }

                let appointment = existingByExternalID[externalID] ?? {
                    let created = Appointment(
                        title: event.summary?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled appointment",
                        startDate: startDate,
                        source: .googleCalendar,
                        externalID: externalID,
                        calendarID: calendarID
                    )
                    modelContext.insert(created)
                    allAppointments.append(created)
                    existingByExternalID[externalID] = created
                    return created
                }()

                appointment.title = event.summary?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled appointment"
                appointment.startDate = startDate
                appointment.endDate = event.end.flatMap(decodeGoogleDate)
                appointment.isAllDay = event.start.date != nil
                appointment.location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                appointment.notes = event.description?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                appointment.source = .googleCalendar
                appointment.externalID = externalID
                appointment.calendarID = calendarID

                seenExternalIDs.insert(externalID)
            }

            pageToken = page.nextPageToken
        } while pageToken != nil

        let removed = removeStaleSyncedAppointments(
            source: .googleCalendar,
            allowedCalendarIDs: [calendarID],
            keepExternalIDs: seenExternalIDs,
            window: window,
            allAppointments: &allAppointments,
            modelContext: modelContext
        )

        return SourceSyncResult(imported: seenExternalIDs.count, removed: removed)
    }

    private func removeStaleSyncedAppointments(
        source: AppointmentSource,
        allowedCalendarIDs: Set<String>,
        keepExternalIDs: Set<String>,
        window: DateInterval,
        allAppointments: inout [Appointment],
        modelContext: ModelContext
    ) -> Int {
        var removed = 0

        for appointment in allAppointments where appointment.source == source {
            if !allowedCalendarIDs.isEmpty {
                guard let calendarID = appointment.calendarID,
                      allowedCalendarIDs.contains(calendarID) else {
                    modelContext.delete(appointment)
                    removed += 1
                    continue
                }
            }

            guard window.contains(appointment.startDate) else { continue }
            guard let externalID = appointment.externalID,
                  !externalID.isEmpty else {
                modelContext.delete(appointment)
                removed += 1
                continue
            }

            if !keepExternalIDs.contains(externalID) {
                modelContext.delete(appointment)
                removed += 1
            }
        }

        if removed > 0 {
            allAppointments.removeAll { appointment in
                guard appointment.source == source else { return false }
                if !allowedCalendarIDs.isEmpty,
                   let calendarID = appointment.calendarID,
                   !allowedCalendarIDs.contains(calendarID) {
                    return true
                }
                guard window.contains(appointment.startDate),
                      let externalID = appointment.externalID,
                      !externalID.isEmpty else {
                    return true
                }
                return !keepExternalIDs.contains(externalID)
            }
        }

        return removed
    }

    private func appleExternalID(for event: EKEvent) -> String {
        let anchor = Int(event.startDate.timeIntervalSince1970)
        let base = event.calendarItemIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return "" }
        return "\(base)::\(anchor)"
    }

    private func normalizedEndDate(start: Date, end: Date?) -> Date? {
        guard let end else { return nil }
        return end > start ? end : nil
    }

    private func requestAppleCalendarAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .writeOnly:
            return true
        case .authorized:
            return true
        case .notDetermined:
            if #available(iOS 17.0, *) {
                return (try? await eventStore.requestFullAccessToEvents()) ?? false
            }
            return false
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func fetchGoogleEventsPage(
        calendarID: String,
        accessToken: String,
        window: DateInterval,
        pageToken: String?
    ) async throws -> GoogleEventsPage {
        let safeCalendarID = calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarID
        guard var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(safeCalendarID)/events") else {
            throw AppointmentSyncError.invalidGoogleRequest
        }

        components.queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "2500"),
            URLQueryItem(name: "timeMin", value: googleDateTimeFormatter.string(from: window.start)),
            URLQueryItem(name: "timeMax", value: googleDateTimeFormatter.string(from: window.end))
        ]

        if let pageToken, !pageToken.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        guard let url = components.url else {
            throw AppointmentSyncError.invalidGoogleRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppointmentSyncError.googleDecodeFailure
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(GoogleErrorEnvelope.self, from: data)
            throw AppointmentSyncError.googleHTTPStatus(httpResponse.statusCode, apiError?.error.message)
        }

        guard let decoded = try? JSONDecoder().decode(GoogleEventsPage.self, from: data) else {
            throw AppointmentSyncError.googleDecodeFailure
        }

        return decoded
    }

    private func decodeGoogleDate(_ value: GoogleEventDate) -> Date? {
        if let dateTime = value.dateTime {
            if let parsed = googleDateTimeFormatterWithFractional.date(from: dateTime) {
                return parsed
            }
            if let parsed = googleDateTimeFormatter.date(from: dateTime) {
                return parsed
            }
        }

        if let date = value.date {
            return parseGoogleAllDayDate(date, timeZoneID: value.timeZone)
        }

        return nil
    }

    private func parseGoogleAllDayDate(_ value: String, timeZoneID: String?) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? TimeZone.current

        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct GoogleEventsPage: Decodable {
    let items: [GoogleEvent]
    let nextPageToken: String?
}

private struct GoogleEvent: Decodable {
    let id: String
    let status: String?
    let summary: String?
    let description: String?
    let location: String?
    let start: GoogleEventDate
    let end: GoogleEventDate?
}

private struct GoogleEventDate: Decodable {
    let dateTime: String?
    let date: String?
    let timeZone: String?
}

private struct GoogleErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let message: String?
    }

    let error: ErrorBody
}
