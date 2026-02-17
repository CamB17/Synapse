import SwiftUI

struct HabitRow: View {
    let title: String
    let streakText: String
    let isCompletedToday: Bool
    let showSparkle: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                ZStack {
                    Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
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

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text(streakText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}
