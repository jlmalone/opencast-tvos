import SwiftUI

// MARK: - ImageDisplayView

/// Displays a cast image (test pattern, screenshot) fullscreen on a black background.
/// Menu button dismisses back to idle.
struct ImageDisplayView: View {
    let url: URL
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .accessibilityLabel("Cast image")
                case .failure:
                    VStack(spacing: 16) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                case .empty:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white.opacity(0.5))
                        .scaleEffect(1.5)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .focusable()
        .onExitCommand {
            onDismiss()
        }
    }
}
