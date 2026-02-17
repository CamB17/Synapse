import SwiftUI

struct HabitRow: View {
    let title: String
    let streakText: String
    let isCompletedToday: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(streakText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}
