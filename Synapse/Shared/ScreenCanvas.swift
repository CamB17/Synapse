import SwiftUI

struct ScreenCanvas<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Theme.canvas
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.topDepthGradient
                    .frame(height: 280)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            content
        }
        .preferredColorScheme(.light)
    }
}
