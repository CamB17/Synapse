import SwiftUI

struct ReviewScoreboard: View {
    struct Tile {
        let title: String
        let value: String
        let subtitle: String?
    }

    let tiles: [Tile]

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm)
    ]

    private var visibleTiles: [Tile] {
        Array(tiles.prefix(4))
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            ForEach(Array(visibleTiles.enumerated()), id: \.offset) { _, tile in
                ScoreTile(tile: tile)
            }
        }
    }
}

private struct ScoreTile: View {
    let tile: ReviewScoreboard.Tile

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(tile.title)
                .font(Theme.Typography.labelCaps)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)

            Text(tile.value)
                .font(Theme.Typography.metricValue)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if let subtitle = tile.subtitle {
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            } else {
                Text(" ")
                    .font(Theme.Typography.caption)
                    .opacity(0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .surfaceCard(style: .primary, cornerRadius: Theme.radiusSmall)
    }
}
