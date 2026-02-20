import SwiftUI
import UIKit

@main
struct FCastReceiverApp: App {

    @State private var playerManager = PlayerManager()
    @State private var server: FCastServer?
    @State private var ipAddress = ""

    var body: some Scene {
        WindowGroup {
            contentView
                .onAppear { setup() }
                .onDisappear { server?.stop() }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if playerManager.isPresenting {
                PlayerView(player: playerManager.avPlayer)
                    .ignoresSafeArea()
            } else {
                IdleView(
                    deviceName: UIDevice.current.name,
                    ipAddress: ipAddress,
                    port: FCastServer.port
                )
            }
        }
    }

    private func setup() {
        ipAddress = NetworkHelper.getLocalIPAddress() ?? ""
        let srv = FCastServer(playerManager: playerManager)
        server = srv
        playerManager.onStateChange = { [weak srv] in
            srv?.broadcastPlaybackUpdate()
        }
        srv.start()
    }
}
