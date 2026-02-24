import Foundation
import SwiftData

@Model
final class HabitCompletion {
    var id: UUID = UUID()
    var habitId: UUID = UUID()
    var day: Date = Date()
    var completedAt: Date = Date()

    init(habitId: UUID, day: Date, completedAt: Date = .now) {
        self.id = UUID()
        self.habitId = habitId
        self.day = Calendar.current.startOfDay(for: day)
        self.completedAt = completedAt
    }
}

@Model
final class HabitPausePeriod {
    var id: UUID = UUID()
    var habitId: UUID = UUID()
    var startDay: Date = Date()
    var endDay: Date?

    init(habitId: UUID, startDay: Date) {
        self.id = UUID()
        self.habitId = habitId
        self.startDay = Calendar.current.startOfDay(for: startDay)
        self.endDay = nil
    }
}
