import SwiftUI

struct OnboardingShellView<Content: View>: View {
    let progress: Double
    let title: String
    let subtitle: String
    let primaryTitle: String?
    let isPrimaryDisabled: Bool
    let showsBack: Bool
    let showsSkip: Bool
    let onBack: () -> Void
    let onSkip: () -> Void
    let onPrimary: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var hasAppeared = false

    init(
        progress: Double,
        title: String,
        subtitle: String,
        primaryTitle: String? = "Continue",
        isPrimaryDisabled: Bool = false,
        showsBack: Bool = true,
        showsSkip: Bool = true,
        onBack: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onPrimary: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.progress = progress
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.isPrimaryDisabled = isPrimaryDisabled
        self.showsBack = showsBack
        self.showsSkip = showsSkip
        self.onBack = onBack
        self.onSkip = onSkip
        self.onPrimary = onPrimary
        self.content = content
    }

    var body: some View {
        ScreenCanvas {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                topRow
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)
                    .animation(
                        Motion.easing.delay(Motion.stagger(0)),
                        value: hasAppeared
                    )

                titleBlock
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)
                    .animation(
                        Motion.easing.delay(Motion.stagger(1)),
                        value: hasAppeared
                    )

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 14)
                    .animation(
                        Motion.easing.delay(Motion.stagger(2)),
                        value: hasAppeared
                    )

                Spacer(minLength: 0)

                if let primaryTitle {
                    Button {
                        withAnimation(Motion.easing) {
                            onPrimary()
                        }
                    } label: {
                        Text(primaryTitle)
                            .font(Theme.Typography.bodySmallStrong)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isPrimaryDisabled ? Theme.textSecondary.opacity(0.35) : Theme.text)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPrimaryDisabled)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 16)
                    .animation(
                        Motion.easing.delay(Motion.stagger(3)),
                        value: hasAppeared
                    )
                }
            }
            .padding(Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
        }
        .onAppear {
            hasAppeared = false
            withAnimation(Motion.easing) {
                hasAppeared = true
            }
        }
    }

    private var topRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                if showsBack {
                    Button("Back") {
                        onBack()
                    }
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.text)
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 44, height: 1)
                }

                Spacer(minLength: 0)

                if showsSkip {
                    Button("Skip") {
                        onSkip()
                    }
                    .font(Theme.Typography.bodySmallStrong)
                    .foregroundStyle(Theme.textSecondary)
                    .buttonStyle(.plain)
                }
            }

            GeometryReader { proxy in
                let width = max(0, min(1, progress)) * proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Theme.surface2)

                    Capsule(style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: width)
                }
            }
            .frame(height: 6)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.titleLarge)
                .foregroundStyle(Theme.text)

            Text(subtitle)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
