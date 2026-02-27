import Foundation

enum TodayCommitment {
    case task(TaskItem)
    case appointment(Appointment)
    case empty
}

enum TodayCommitmentResolver {
    static func resolve(
        selectedDay: Date,
        upNextTask: TaskItem?,
        fallbackTask: TaskItem?,
        nextUpcomingAppointment: Appointment?,
        now: Date = .now,
        appointmentHorizonHours: Int = 6,
        calendar: Calendar = .current
    ) -> TodayCommitment {
        let selectedDayStart = calendar.startOfDay(for: selectedDay)
        let todayStart = calendar.startOfDay(for: now)
        let isToday = calendar.isDate(selectedDayStart, inSameDayAs: todayStart)

        if isToday, let appointment = nextUpcomingAppointment {
            let horizon = calendar.date(byAdding: .hour, value: appointmentHorizonHours, to: now) ?? now
            if appointment.startDate <= horizon && appointment.resolvedEndDate >= now {
                return .appointment(appointment)
            }
        }

        if let upNextTask {
            return .task(upNextTask)
        }

        if let fallbackTask {
            return .task(fallbackTask)
        }

        return .empty
    }
}
