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

            VStack(alignment: .leading, spacing: Theme.Spacing.compact) {
                Text(title)
                    .font(Theme.Typography.panelTitle)
                    .foregroundStyle(Theme.text)

                Text(subtitle)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}
