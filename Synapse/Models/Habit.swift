import Foundation
import SwiftData

enum HabitFrequency: String, Codable, CaseIterable {
    case daily
    case weekly
    case custom

    var displayLabel: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .custom: return "Custom"
        }
    }
}

@Model
final class Habit {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    @Attribute(originalName: "lastCompletedAt")
    var lastCompletedDate: Date?
    @Attribute(originalName: "streakCount")
    var currentStreak: Int = 0
    var isActive: Bool = true
    var frequencyRaw: String = HabitFrequency.daily.rawValue
    var timeOfDayRaw: String = TaskPartOfDay.anytime.rawValue
    var scheduledWeekdaysRaw: String = ""
    var sortOrder: Int = 0
    var groupID: String?

    init(
        title: String,
        frequency: HabitFrequency = .daily,
        timeOfDay: TaskPartOfDay = .anytime,
        scheduledWeekdays: Set<Int> = [],
        sortOrder: Int = 0,
        groupID: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.lastCompletedDate = nil
        self.currentStreak = 0
        self.isActive = true
        self.frequencyRaw = frequency.rawValue
        self.timeOfDayRaw = timeOfDay.rawValue
        self.scheduledWeekdaysRaw = Self.encodeWeekdays(sanitizedWeekdays(from: scheduledWeekdays))
        self.sortOrder = sortOrder
        self.groupID = groupID
    }

    var completedToday: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    func completeToday() {
        let now = Date()
        let calendar = Calendar.current

        if let last = lastCompletedDate {
            if calendar.isDateInYesterday(last) {
                currentStreak += 1
            } else if !calendar.isDateInToday(last) {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        lastCompletedDate = now
    }

    func uncompleteToday() {
        guard completedToday else { return }

        if currentStreak <= 1 {
            currentStreak = 0
            lastCompletedDate = nil
            return
        }

        currentStreak -= 1
        lastCompletedDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
    }

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var timeOfDay: TaskPartOfDay {
        get { TaskPartOfDay(rawValue: timeOfDayRaw) ?? .anytime }
        set { timeOfDayRaw = newValue.rawValue }
    }

    var scheduledWeekdays: Set<Int> {
        get {
            let parsed = Self.decodeWeekdays(scheduledWeekdaysRaw)
            if parsed.isEmpty {
                let fallback = Calendar.current.component(.weekday, from: createdAt)
                return [fallback]
            }
            return parsed
        }
        set {
            scheduledWeekdaysRaw = Self.encodeWeekdays(sanitizedWeekdays(from: newValue))
        }
    }

    func isScheduled(on day: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: day)

        switch frequency {
        case .daily:
            return true
        case .weekly, .custom:
            return scheduledWeekdays.contains(weekday)
        }
    }

    var frequencySummary: String {
        switch frequency {
        case .daily:
            return HabitFrequency.daily.displayLabel
        case .weekly:
            return "\(HabitFrequency.weekly.displayLabel) (\(weekdaySummary(limit: 1)))"
        case .custom:
            return "\(HabitFrequency.custom.displayLabel) (\(weekdaySummary(limit: 7)))"
        }
    }

    private func weekdaySummary(limit: Int) -> String {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let ordered = scheduledWeekdays.sorted()

        guard !ordered.isEmpty else { return "-" }

        let names = ordered.map { index -> String in
            let safeIndex = max(1, min(7, index)) - 1
            return symbols[safeIndex]
        }
        if names.count > limit {
            return "\(names.prefix(limit).joined(separator: ", ")) +\(names.count - limit)"
        }
        return names.joined(separator: ", ")
    }

    private func sanitizedWeekdays(from input: Set<Int>) -> Set<Int> {
        let clipped = input.filter { (1...7).contains($0) }
        if clipped.isEmpty {
            return [Calendar.current.component(.weekday, from: createdAt)]
        }
        return clipped
    }

    private static func decodeWeekdays(_ raw: String) -> Set<Int> {
        let values = raw
            .split(separator: ",")
            .compactMap { Int($0) }
            .filter { (1...7).contains($0) }
        return Set(values)
    }

    private static func encodeWeekdays(_ weekdays: Set<Int>) -> String {
        weekdays.sorted().map(String.init).joined(separator: ",")
    }
}
