import Foundation

enum HabitTrendService {
    static func lastSevenDays(
        for habitID: UUID,
        endingOn day: Date,
        completionDaysByHabit: [UUID: Set<Date>],
        calendar: Calendar = .current
    ) -> [Bool] {
        let endDay = calendar.startOfDay(for: day)
        let completionDays = completionDaysByHabit[habitID] ?? []

        return (0..<7).compactMap { index -> Bool? in
            let dayOffset = index - 6
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: endDay) else {
                return nil
            }
            return completionDays.contains(calendar.startOfDay(for: targetDay))
        }
    }

    static func todayIndex(
        endingOn day: Date,
        calendar: Calendar = .current
    ) -> Int? {
        let endDay = calendar.startOfDay(for: day)
        let rangeStart = calendar.date(byAdding: .day, value: -6, to: endDay) ?? endDay
        let today = calendar.startOfDay(for: .now)
        let offset = calendar.dateComponents([.day], from: rangeStart, to: today).day ?? 0

        guard offset >= 0 && offset < 7 else { return nil }
        return offset
    }
}
