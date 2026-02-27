import SwiftUI

struct TodayHeroModule: View {
    let timeOfDayLabel: String
    let commitment: TodayCommitment
    let tasksRemainingCount: Int
    let focusMinutesToday: Int
    let onStartFocus: () -> Void
    let onViewAppointment: (Appointment) -> Void
    let onChooseTask: () -> Void
    let onQuickAdd: () -> Void
    let onViewDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("NOW")
                    .font(Theme.Typography.labelCaps)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)

                Text(timeOfDayLabel)
                    .font(Theme.Typography.labelCaps)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.accent)
                    .textCase(.uppercase)

                Spacer(minLength: 0)
            }

            Text(titleLine)
                .font(Theme.Typography.heroTitle)
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(primarySignal)
                    .font(Theme.Typography.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)

                if let secondarySignal {
                    Text(secondarySignal)
                        .font(Theme.Typography.bodySmall)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    handlePrimaryAction()
                } label: {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text(primaryButtonTitle)
                        Image(systemName: "arrow.right")
                            .font(Theme.Typography.caption.weight(.semibold))
                    }
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.accent.opacity(0.16))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
                    }
                }
                .buttonStyle(TodayPressableButtonStyle())

                Button {
                    handleSecondaryAction()
                } label: {
                    HStack(spacing: Theme.Spacing.xxxs) {
                        Text(secondaryButtonTitle)
                        Image(systemName: "chevron.right")
                            .font(Theme.Typography.caption.weight(.semibold))
                    }
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(TodayPressableButtonStyle())

                Spacer(minLength: 0)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .premiumGlassCard(cornerRadius: 14, shadowStrength: 1)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.text.opacity(0.08), lineWidth: 1)
        }
    }

    private var titleLine: String {
        switch commitment {
        case let .task(task):
            let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Untitled task" : trimmed
        case let .appointment(appointment):
            let trimmed = appointment.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Upcoming appointment" : trimmed
        case .empty:
            return "Pick today's commitment"
        }
    }

    private var primarySignal: String {
        switch commitment {
        case .task:
            let remaining = max(0, tasksRemainingCount)
            let suffix = remaining == 1 ? "" : "s"
            return "\(remaining) task\(suffix) remaining today"
        case let .appointment(appointment):
            if appointment.isAllDay {
                return "Next appointment: all day"
            }
            return "Next appointment \(appointment.startDate.formatted(.dateTime.hour().minute()))"
        case .empty:
            return "Choose one task to anchor the day."
        }
    }

    private var secondarySignal: String? {
        guard focusMinutesToday > 0 else { return nil }
        return "Focus today: \(formattedMinutes(focusMinutesToday))"
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        if safeMinutes < 60 {
            return "\(safeMinutes)m"
        }
        let hours = safeMinutes / 60
        let remainder = safeMinutes % 60
        return "\(hours)h \(remainder)m"
    }

    private var primaryButtonTitle: String {
        switch commitment {
        case .task:
            return "Start focus"
        case .appointment:
            return "View"
        case .empty:
            return "Pick commitment"
        }
    }

    private var secondaryButtonTitle: String {
        switch commitment {
        case .appointment:
            return "View details"
        case .task, .empty:
            return "Quick add"
        }
    }

    private func handlePrimaryAction() {
        switch commitment {
        case .task:
            onStartFocus()
        case let .appointment(appointment):
            onViewAppointment(appointment)
        case .empty:
            onChooseTask()
        }
    }

    private func handleSecondaryAction() {
        switch commitment {
        case .appointment:
            onViewDetails()
        case .task, .empty:
            onQuickAdd()
        }
    }
}
