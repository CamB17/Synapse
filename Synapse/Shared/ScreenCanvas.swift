import SwiftUI

struct ScreenCanvas<Content: View>: View {
    private let daySeed: Date
    private let showsTopDepthGradient: Bool
    private let topDepthOpacity: Double
    let content: Content

    init(
        daySeed: Date = .now,
        showsTopDepthGradient: Bool = true,
        topDepthOpacity: Double = 1,
        @ViewBuilder content: () -> Content
    ) {
        self.daySeed = daySeed
        self.showsTopDepthGradient = showsTopDepthGradient
        self.topDepthOpacity = topDepthOpacity
        self.content = content()
    }

    var body: some View {
        ZStack {
            Theme.canvas(for: daySeed)
                .ignoresSafeArea()

            if showsTopDepthGradient {
                VStack(spacing: 0) {
                    Theme.topDepthGradient(for: daySeed)
                        .opacity(topDepthOpacity)
                        .frame(height: 220)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
            }

            content
        }
        .animation(.easeInOut(duration: 0.35), value: daySeed)
        .preferredColorScheme(.light)
    }
}
