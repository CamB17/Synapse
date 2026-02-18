import SwiftUI

struct SectionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent.opacity(0.45))

            Text(title)
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.textSecondary)
                .tracking(Theme.Typography.sectionTracking)
        }
    }
}
