import SwiftUI
import UIKit

// MARK: - ContentView
//
// This MUST be a separate View struct (not a @ViewBuilder property on App)
// so that SwiftUI's @Observable tracking fires correctly when
// playerManager.isPresenting changes. App.body uses a Scene/WindowGroup
// context that doesn't trigger @Observable invalidation the same way
// View.body does.

struct ContentView: View {
    let playerManager: PlayerManager   // @Observable — auto-tracked in body
    let port: UInt16

    @State private var ipAddress = ""

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
        }
        .onAppear {
            ipAddress = NetworkHelper.getLocalIPAddress() ?? ""
        }
    }
}
