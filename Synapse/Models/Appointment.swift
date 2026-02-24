import Foundation
import SwiftData

enum AppointmentSource: String, Codable, CaseIterable {
    case manual
    case appleCalendar
    case googleCalendar

    var displayLabel: String {
        switch self {
        case .manual:
            return "Manual"
        case .appleCalendar:
            return "Apple"
        case .googleCalendar:
            return "Google"
        }
    }
}

@Model
final class Appointment {
    static let defaultTimedDuration: TimeInterval = 60 * 60

    var id: UUID = UUID()
    var title: String = ""
    var startDate: Date = Date()
    var endDate: Date?
    var isAllDay: Bool = false
    var location: String?
    var notes: String?
    var sourceRaw: String = AppointmentSource.manual.rawValue
    var externalID: String?
    var calendarID: String?

    init(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        source: AppointmentSource = .manual,
        externalID: String? = nil,
        calendarID: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.sourceRaw = source.rawValue
        self.externalID = externalID
        self.calendarID = calendarID
    }

    var source: AppointmentSource {
        get { AppointmentSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var resolvedEndDate: Date {
        if let endDate {
            return endDate
        }

        if isAllDay {
            let startDay = Calendar.current.startOfDay(for: startDate)
            return Calendar.current.date(byAdding: .day, value: 1, to: startDay) ?? startDate.addingTimeInterval(86_400)
        }

        return startDate.addingTimeInterval(Self.defaultTimedDuration)
    }
}
