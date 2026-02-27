import SwiftUI

struct TodayHeroModule: View {
    let timeOfDayLabel: String
    let commitment: TodayCommitment
    let tasksRemainingCount: Int
    let nextAppointmentSummary: String?
    let onStartFocus: () -> Void
    let onViewAppointment: (Appointment) -> Void
    let onChooseTask: () -> Void
    let onQuickAdd: () -> Void
    let onViewDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                Text("NOW")
                    .font(Theme.Typography.labelCaps)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)

                Text(timeOfDayLabel.uppercased())
                    .font(Theme.Typography.caption)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .frame(height: 24)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Theme.accent.opacity(0.12))
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
                    }

                Spacer(minLength: 0)
            }

            commitmentTitleView

            HStack(spacing: Theme.Spacing.xxs) {
                Text(subtitleLine)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .monospacedDigit()

                if case .appointment = commitment {
                    Button {
                        onViewDetails()
                    } label: {
                        Text("Details")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(TodayPressableButtonStyle())
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    onStartFocus()
                } label: {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text("Start focus")
                        Image(systemName: "arrow.right")
                            .font(Theme.Typography.caption.weight(.semibold))
                    }
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.surface)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.accent)
                    )
                }
                .buttonStyle(TodayPressableButtonStyle())

                Button {
                    onQuickAdd()
                } label: {
                    HStack(spacing: Theme.Spacing.xxxs) {
                        Text("Quick add")
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
        .padding(Theme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.14),
                            Theme.surface.opacity(0.95),
                            Theme.accent2.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.accent.opacity(0.24), lineWidth: 1)
        }
        .shadow(color: Theme.accent.opacity(0.10), radius: 14, y: 6)
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

    @ViewBuilder
    private var commitmentTitleView: some View {
        switch commitment {
        case let .appointment(appointment):
            Button {
                onViewAppointment(appointment)
            } label: {
                Text(titleLine)
                    .font(Theme.Typography.heroTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(TodayPressableButtonStyle())
        case .empty:
            Button {
                onChooseTask()
            } label: {
                Text(titleLine)
                    .font(Theme.Typography.heroTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(TodayPressableButtonStyle())
        case .task:
            Text(titleLine)
                .font(Theme.Typography.heroTitle)
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tasksSummary: String {
        let remaining = max(0, tasksRemainingCount)
        return remaining == 1 ? "1 task left" : "\(remaining) tasks left"
    }

    private var appointmentSummary: String {
        if let nextAppointmentSummary {
            return "next appt \(nextAppointmentSummary)"
        }
        return "no appointments soon"
    }

    private var subtitleLine: String {
        "\(tasksSummary) • \(appointmentSummary)"
    }
}
