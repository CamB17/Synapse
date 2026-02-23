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
                    Circle()
                        .stroke(
                            isCompletedToday ? Theme.accent.opacity(0.62) : Theme.textSecondary.opacity(0.5),
                            lineWidth: 1.25
                        )
                        .frame(width: 22, height: 22)

                    if isCompletedToday {
                        Circle()
                            .fill(Theme.accent.opacity(0.12))
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }

                    if showSparkle {
                        SparkleOverlay()
                    }
                }
                .scaleEffect(showSparkle ? 1.12 : 1)
                .animation(.spring(response: 0.22, dampingFraction: 0.65), value: showSparkle)
                .animation(.snappy(duration: 0.16), value: isCompletedToday)
            }
            .buttonStyle(RitualTapStyle())

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Typography.itemTitle)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.56))
                    Text("Recurring")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                }
            }

            Spacer()
        }
        .frame(minHeight: 42, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xs)
    }
}

private struct RitualTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
