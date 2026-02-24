import Foundation
import SwiftData

@Model
final class CalendarSyncSettings {
    var id: UUID = UUID()
    var appleSyncEnabled: Bool = false
    var appleCalendarIDsRaw: String = ""
    var includeBirthdays: Bool = true
    var googleSyncEnabled: Bool = false
    var googleCalendarID: String?
    var googleAccessToken: String?
    var lastAppleSyncAt: Date?
    var lastGoogleSyncAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {
        self.id = UUID()
        self.appleSyncEnabled = false
        self.appleCalendarIDsRaw = ""
        self.includeBirthdays = true
        self.googleSyncEnabled = false
        self.googleCalendarID = nil
        self.googleAccessToken = nil
        self.lastAppleSyncAt = nil
        self.lastGoogleSyncAt = nil
        self.createdAt = .now
        self.updatedAt = .now
    }

    var appleCalendarIDs: Set<String> {
        get {
            Set(
                appleCalendarIDsRaw
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }
        set {
            appleCalendarIDsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .sorted()
                .joined(separator: ",")
        }
    }

    func touch() {
        updatedAt = .now
    }
}
