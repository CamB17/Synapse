import SwiftUI

struct UniversalCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onAddTask: () -> Void
    let onAddAppointment: (() -> Void)?
    let onAddHabit: () -> Void
    let onStartFocus: (() -> Void)?

    var body: some View {
        ScreenCanvas {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                header

                actionRow(icon: "checklist", title: "Add Task") {
                    dismiss()
                    onAddTask()
                }

                if let onAddAppointment {
                    actionRow(icon: "calendar.badge.plus", title: "Add Appointment") {
                        dismiss()
                        onAddAppointment()
                    }
                }

                actionRow(icon: "leaf", title: "Add Habit") {
                    dismiss()
                    onAddHabit()
                }

                if let onStartFocus {
                    actionRow(icon: "timer", title: "Start Focus Session") {
                        dismiss()
                        onStartFocus()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, 28)
            .padding(.bottom, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Capture")
                .font(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.text)

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Theme.surface2)
                    )
                    .overlay {
                        Circle()
                            .stroke(Theme.textSecondary.opacity(0.15), lineWidth: 0.8)
                    }
                }
            .buttonStyle(.plain)
            .accessibilityLabel("Close capture")
        }
    }

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: icon)
                        .font(Theme.Typography.iconCompact)
                        .foregroundStyle(Theme.accent)
                }

                Text(title)
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.75))
            }
            .padding(.horizontal, Theme.Spacing.cardInset)
            .padding(.vertical, Theme.Spacing.sm)
            .surfaceCard(cornerRadius: Theme.radiusSmall)
        }
        .buttonStyle(.plain)
    }
}
