import SwiftUI

/// Safe SwiftUI-only LottieView fallback. This presents a simple animated
/// checkmark when `play` is toggled. It's intentionally implemented without
/// requiring the Lottie package so the project builds cleanly. If you add
/// the `lottie-ios` Swift package, we can reintroduce the native Lottie
/// UIViewRepresentable implementation later.
struct LottieView: View {
    let filename: String
    @Binding var play: Bool

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 120, height: 120)
            .foregroundColor(Theme.accentColor)
            .scaleEffect(play ? 1.0 : 0.6)
            .opacity(play ? 1.0 : 0.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: play)
            .onChange(of: play) { new in
                if new {
                    // Reset play after a short delay so the animation can be retriggered.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                        play = false
                    }
                }
            }
    }
}

// Quick preview for the fallback animation
#if DEBUG
struct LottieView_Previews: PreviewProvider {
    struct Wrapper: View {
        @State var play = false
        var body: some View {
            VStack(spacing: 20) {
                LottieView(filename: "success_check", play: $play)
                Button("Play") { play = true }
            }
            .padding()
            .background(Theme.backgroundColor)
        }
    }

    static var previews: some View {
        Wrapper().preferredColorScheme(.dark)
    }
}
#endif
