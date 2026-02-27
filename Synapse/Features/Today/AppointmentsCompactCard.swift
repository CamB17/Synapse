import SwiftUI
import UIKit

private enum TodayHaptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct AppointmentsCompactCard: View {
    struct SoonAppointment {
        let id: UUID
        let title: String
        let timeLabel: String
        let location: String?
    }

    let soonAppointment: SoonAppointment?
    let isHeroShowingAppointment: Bool
    let onOpenSoon: (UUID) -> Void
    let onViewAll: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Appointments")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 0)
                textAction(title: "Add", action: onAdd)
                textAction(title: "View all", action: onViewAll)
            }

            if let soonAppointment {
                appointmentRow(soonAppointment)
            } else {
                compactState
            }
        }
        .padding(.horizontal, 2)
    }

    private func appointmentRow(_ appointment: SoonAppointment) -> some View {
        Button {
            TodayHaptics.light()
            onOpenSoon(appointment.id)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text(appointment.title)
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)

                    HStack(spacing: Theme.Spacing.xxxs) {
                        Text(appointment.timeLabel)
                            .font(Theme.Typography.caption)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)

                        if let location = appointment.location, !location.isEmpty {
                            Text("•")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                            Text(location)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .buttonStyle(TodayPressableButtonStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xxxs)
    }

    private var compactState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
            Text("No appointments soon")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xxxs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textAction(title: String, action: @escaping () -> Void) -> some View {
        Button {
            TodayHaptics.light()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.xxxs) {
                Text(title)
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption.weight(.semibold))
            }
            .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .buttonStyle(TodayPressableButtonStyle())
    }
}
