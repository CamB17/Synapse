import SwiftUI

struct EmptyStatePanel: View {
    let symbol: String
    let title: String
    let subtitle: String
    var playful = false
    var showSparkle = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                Illustration(symbol: symbol, style: playful ? .playful : .line, size: 34)
                if showSparkle {
                    SparkleOverlay()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)

                Text(subtitle)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}
