import SwiftUI

struct HabitRow: View {
    let title: String
    let isCompletedToday: Bool
    let showSparkle: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                onToggle()
            } label: {
                ZStack {
                    Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(Theme.Typography.iconLarge)
                        .foregroundStyle(isCompletedToday ? Theme.accent : Theme.textSecondary)
                        .symbolRenderingMode(.hierarchical)

                    if showSparkle {
                        SparkleOverlay()
                    }
                }
                .scaleEffect(showSparkle ? 1.12 : 1)
                .animation(.spring(response: 0.22, dampingFraction: 0.65), value: showSparkle)
                .animation(.snappy(duration: 0.16), value: isCompletedToday)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    Text("Recurring")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.75))
                }
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}
