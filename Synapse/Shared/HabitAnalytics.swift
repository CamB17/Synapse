import Foundation

enum HabitAnalytics {
    static func isHabit(
        _ habit: Habit,
        activeOn day: Date,
        today: Date = .now,
        pausePeriods: [HabitPausePeriod],
        calendar: Calendar = .current
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: today)
        let createdDay = calendar.startOfDay(for: habit.createdAt)

        guard dayStart >= createdDay else { return false }
        guard habit.isScheduled(on: dayStart, calendar: calendar) else { return false }

        let periods = pausePeriods.filter { $0.habitId == habit.id }

        if !habit.isActive, periods.allSatisfy({ $0.endDay != nil }), dayStart >= todayStart {
            return false
        }

        for period in periods {
            let start = calendar.startOfDay(for: period.startDay)
            let end = calendar.startOfDay(for: period.endDay ?? .distantFuture)
            if dayStart >= start && dayStart < end {
                return false
            }
        }

        return true
    }

    static func completionDays(
        for habitID: UUID,
        completions: [HabitCompletion],
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(
            completions
                .filter { $0.habitId == habitID }
                .map { calendar.startOfDay(for: $0.day) }
        )
    }

    static func currentStreak(
        for habit: Habit,
        completions: [HabitCompletion],
        pausePeriods: [HabitPausePeriod],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let createdDay = calendar.startOfDay(for: habit.createdAt)
        let completedDays = completionDays(for: habit.id, completions: completions, calendar: calendar)

        var streak = 0
        var scanned = 0
        var cursor = todayStart

        while cursor >= createdDay && scanned < 3650 {
            if isHabit(habit, activeOn: cursor, today: todayStart, pausePeriods: pausePeriods, calendar: calendar) {
                if completedDays.contains(cursor) {
                    streak += 1
                } else {
                    break
                }
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            scanned += 1
        }

        return streak
    }

    static func monthlyCompletion(
        for habit: Habit,
        monthStart: Date,
        completions: [HabitCompletion],
        pausePeriods: [HabitPausePeriod],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> (completedDays: Int, eligibleDays: Int, percent: Int) {
        let start = calendar.startOfDay(for: monthStart)
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let evaluationEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? monthEnd)

        guard evaluationEnd > start else {
            return (0, 0, 0)
        }

        let completedDays = completionDays(for: habit.id, completions: completions, calendar: calendar)

        var eligible = 0
        var completed = 0
        var cursor = start

        while cursor < evaluationEnd {
            if isHabit(habit, activeOn: cursor, today: today, pausePeriods: pausePeriods, calendar: calendar) {
                eligible += 1
                if completedDays.contains(cursor) {
                    completed += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let percent = eligible == 0 ? 0 : Int((Double(completed) / Double(eligible) * 100).rounded())
        return (completed, eligible, percent)
    }

    static func bestStreakInMonth(
        for habit: Habit,
        monthStart: Date,
        completions: [HabitCompletion],
        pausePeriods: [HabitPausePeriod],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: monthStart)
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let evaluationEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? monthEnd)

        guard evaluationEnd > start else { return 0 }

        let completedDays = completionDays(for: habit.id, completions: completions, calendar: calendar)

        var best = 0
        var run = 0
        var cursor = start

        while cursor < evaluationEnd {
            if isHabit(habit, activeOn: cursor, today: today, pausePeriods: pausePeriods, calendar: calendar) {
                if completedDays.contains(cursor) {
                    run += 1
                    best = max(best, run)
                } else {
                    run = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return best
    }
}
