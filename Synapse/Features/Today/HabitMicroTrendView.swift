import SwiftUI

struct HabitMicroTrendView: View {
    let values: [Bool]
    let todayIndex: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, isComplete in
                Circle()
                    .fill(isComplete ? Theme.accent.opacity(0.62) : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay {
                        Circle()
                            .stroke(
                                isComplete ? Theme.accent.opacity(0.72) : Theme.textSecondary.opacity(0.32),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        if index == todayIndex {
                            Circle()
                                .stroke(Theme.text.opacity(0.65), lineWidth: 1.1)
                                .padding(-1.8)
                        }
                    }
            }
        }
    }
}
