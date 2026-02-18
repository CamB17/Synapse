import SwiftUI

enum StatusChipTone {
    case accent
    case accent2
    case neutral
}

struct StatusChip: View {
    let text: String
    var icon: String? = nil
    var tone: StatusChipTone = .accent
    var uppercased = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(uppercased ? text.uppercased() : text)
                .font(Theme.Typography.chipLabel)
                .tracking(0.7)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(background)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(border, lineWidth: 0.5)
        )
    }

    private var foreground: Color {
        switch tone {
        case .accent:
            return Theme.accent.opacity(0.9)
        case .accent2:
            return Theme.accent2
        case .neutral:
            return Theme.textSecondary
        }
    }

    private var background: Color {
        switch tone {
        case .accent:
            return Theme.accent.opacity(0.1)
        case .accent2:
            return Theme.accent2.opacity(0.12)
        case .neutral:
            return Theme.textSecondary.opacity(0.12)
        }
    }

    private var border: Color {
        switch tone {
        case .accent:
            return Theme.accent.opacity(0.16)
        case .accent2:
            return Theme.accent2.opacity(0.2)
        case .neutral:
            return Theme.textSecondary.opacity(0.2)
        }
    }
}
