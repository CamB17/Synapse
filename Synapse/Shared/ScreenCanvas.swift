import SwiftUI

struct ScreenCanvas<Content: View>: View {
    private let daySeed: Date
    let content: Content

    init(daySeed: Date = .now, @ViewBuilder content: () -> Content) {
        self.daySeed = daySeed
        self.content = content()
    }

    var body: some View {
        ZStack {
            Theme.canvas(for: daySeed)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.topDepthGradient(for: daySeed)
                    .frame(height: 280)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            content
        }
        .animation(.easeInOut(duration: 0.35), value: daySeed)
        .preferredColorScheme(.light)
    }
}
