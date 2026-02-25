import SwiftUI

struct FocusCompletionSheet: View {
    let taskTitle: String?
    let onMarkDone: () -> Void
    let onNotYet: () -> Void
    let onStartAnother: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Nice work.")
                .font(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.text)

            if let taskTitle, !taskTitle.isEmpty {
                Text("Want to mark it done?")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.textSecondary)

                Text(taskTitle)
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.xs) {
                    Button("Mark done") {
                        onMarkDone()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)

                    Button("Not yet") {
                        onNotYet()
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: Theme.Spacing.xs) {
                Button("Start another session") {
                    onStartAnother()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent2)

                Button("Close") {
                    onClose()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .stroke(Theme.textSecondary.opacity(0.12), lineWidth: 0.8)
        )
    }
}
