import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID
    var title: String
    var createdAt: Date
    @Attribute(originalName: "lastCompletedAt")
    var lastCompletedDate: Date?
    @Attribute(originalName: "streakCount")
    var currentStreak: Int
    var isActive: Bool

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.lastCompletedDate = nil
        self.currentStreak = 0
        self.isActive = true
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
}
