import SwiftUI

struct AppointmentRow: View {
    let appointment: Appointment
    let day: Date
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: appointment.isAllDay ? "calendar" : "clock")
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary.opacity(0.84))
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text(appointment.title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.xxs) {
                    Text(AppointmentPresentation.timeLabel(for: appointment, day: day))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary)

                    if let location = appointment.location, !location.isEmpty {
                        Text("•")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary.opacity(0.7))
                        Text(location)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(appointment.source.displayLabel)
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary.opacity(0.9))
                .padding(.horizontal, Theme.Spacing.xxs)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.surface2.opacity(0.82))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Theme.textSecondary.opacity(0.14), lineWidth: 0.8)
                }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface.opacity(0.7))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.textSecondary.opacity(0.1), lineWidth: 0.8)
        }
    }
}

enum AppointmentPresentation {
    static func occurs(_ appointment: Appointment, on day: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        if appointment.isAllDay {
            let eventStart = calendar.startOfDay(for: appointment.startDate)
            let rawEnd = appointment.endDate ?? calendar.date(byAdding: .day, value: 1, to: eventStart)
            let eventEnd = calendar.startOfDay(for: rawEnd ?? eventStart.addingTimeInterval(86_400))
            let adjustedEnd = max(eventEnd, calendar.date(byAdding: .day, value: 1, to: eventStart) ?? eventStart.addingTimeInterval(86_400))
            return eventStart < dayEnd && adjustedEnd > dayStart
        }

        let eventStart = appointment.startDate
        let eventEnd = max(appointment.resolvedEndDate, eventStart)
        return eventStart < dayEnd && eventEnd > dayStart
    }

    static func timeLabel(for appointment: Appointment, day: Date, calendar: Calendar = .current) -> String {
        if appointment.isAllDay {
            return "All day"
        }

        let dayStart = calendar.startOfDay(for: day)
        let selectedDayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let start = max(appointment.startDate, dayStart)
        let end = min(appointment.resolvedEndDate, selectedDayEnd)

        let startText = start.formatted(.dateTime.hour().minute())
        if appointment.endDate != nil {
            let endText = end.formatted(.dateTime.hour().minute())
            return "\(startText) - \(endText)"
        }
        return startText
    }
}
