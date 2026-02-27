import Foundation

enum AchievementEngine {
    static func isPerfectDay(
        habitTotal: Int,
        habitCompleted: Int,
        scheduledTasks: Int,
        completedTasks: Int,
        focusSessionCount: Int,
        focusMinutes: Int,
        habitCompletionThreshold: Double = 0.8,
        taskCompletionThreshold: Double = 0.6,
        minimumFocusMinutes: Int = 20
    ) -> Bool {
        let hasHabits = habitTotal > 0
        let habitRatio = hasHabits ? (Double(habitCompleted) / Double(habitTotal)) : 0
        let habitsMet = hasHabits && habitRatio >= habitCompletionThreshold

        let hasTasks = scheduledTasks > 0
        let taskRatio = hasTasks ? (Double(completedTasks) / Double(scheduledTasks)) : 0
        let tasksMet = hasTasks && taskRatio >= taskCompletionThreshold

        let focusMet = focusSessionCount > 0 || focusMinutes >= minimumFocusMinutes

        return habitsMet && tasksMet && focusMet
    }
}
