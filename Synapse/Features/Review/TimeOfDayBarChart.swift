import SwiftUI

struct TimeOfDayBarChart: View {
    let morning: Int
    let afternoon: Int
    let evening: Int

    private struct Bucket: Identifiable {
        let id = UUID()
        let title: String
        let minutes: Int
    }

    private var buckets: [Bucket] {
        [
            Bucket(title: "Morning", minutes: morning),
            Bucket(title: "Afternoon", minutes: afternoon),
            Bucket(title: "Evening", minutes: evening)
        ]
    }

    private var maxMinutes: Int {
        max(1, buckets.map(\.minutes).max() ?? 1)
    }

    private var totalMinutes: Int {
        max(0, morning + afternoon + evening)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Focus by time of day")
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.text)

                Spacer(minLength: 0)

                Text("Total \(formattedMinutes(totalMinutes))")
                    .font(Theme.Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: Theme.Spacing.xs) {
                ForEach(buckets) { bucket in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                        HStack {
                            Text(bucket.title)
                                .font(Theme.Typography.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)

                            Spacer(minLength: 0)

                            Text(formattedMinutes(bucket.minutes))
                                .font(Theme.Typography.caption)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary.opacity(0.86))
                        }

                        GeometryReader { proxy in
                            let width = proxy.size.width * CGFloat(bucket.minutes) / CGFloat(maxMinutes)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Theme.surface2.opacity(0.9))
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Theme.accent.opacity(0.58))
                                    .frame(width: max(2, width))
                            }
                        }
                        .frame(height: 14)
                    }
                }
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .primary, cornerRadius: Theme.radiusSmall)
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
}
