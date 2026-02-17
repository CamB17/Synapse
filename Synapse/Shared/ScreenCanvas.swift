import SwiftUI

struct ScreenCanvas<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Theme.heroGradient
                .opacity(0.55)
                .ignoresSafeArea()

            Theme.canvas
                .opacity(0.85)
                .ignoresSafeArea()

            content
        }
        .preferredColorScheme(.light)
    }
}
