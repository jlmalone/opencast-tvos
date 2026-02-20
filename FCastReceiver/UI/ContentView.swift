import SwiftUI
import UIKit

// MARK: - ContentView
//
// Must be a separate View struct so @Observable tracking fires inside
// View.body (App.body with WindowGroup doesn't trigger it reliably).

struct ContentView: View {
    let playerManager: PlayerManager
    let port: UInt16

    @State private var ipAddress = ""
    @State private var showError = false
    @State private var errorText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if playerManager.isPresenting {
                PlayerView(player: playerManager.avPlayer)
                    .ignoresSafeArea()
            } else {
                IdleView(
                    deviceName: UIDevice.current.name,
                    ipAddress: ipAddress,
                    port: port
                )
            }

            // Error banner — shown when a cast attempt fails (unsupported format, etc.)
            if showError {
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 28))
                        Text(errorText)
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showError)
        .animation(.easeInOut(duration: 0.3), value: playerManager.isPresenting)
        .onAppear {
            ipAddress = NetworkHelper.getLocalIPAddress() ?? ""
        }
        .onChange(of: playerManager.lastError) { _, newError in
            guard let newError else { return }
            errorText = newError
            withAnimation { showError = true }
            // Auto-dismiss after 6 seconds
            Task {
                try? await Task.sleep(for: .seconds(6))
                withAnimation { showError = false }
            }
        }
    }
}
