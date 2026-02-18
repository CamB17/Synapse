import SwiftUI

struct SparkleOverlay: View {
    @State private var show = false

    var body: some View {
        ZStack {
            if show {
                Image(systemName: "sparkles")
                    .font(Theme.Typography.iconCompact)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.accent2.opacity(0.9))
                    .transition(.scale.combined(with: .opacity))
                    .offset(x: Theme.Spacing.md, y: -Theme.Spacing.cardInset)
            }
        }
        .onAppear {
            withAnimation(.snappy(duration: 0.18)) { show = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.snappy(duration: 0.18)) { show = false }
            }
        }
    }
}
