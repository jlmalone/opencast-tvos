import SwiftUI

@main
struct OpenCastApp: App {

    @State private var playerManager = PlayerManager()
    @State private var server: FCastServer?

    var body: some Scene {
        WindowGroup {
            // ContentView is a proper View struct — @Observable tracking works
            // correctly inside View.body (not App.body). This is critical for
            // playerManager.isPresenting changes to trigger UI updates.
            ContentView(playerManager: playerManager, port: FCastServer.port)
                .onAppear { setup() }
                .onDisappear { server?.stop() }
        }
    }

    @MainActor
    private func setup() {
        let srv = FCastServer(playerManager: playerManager)
        server = srv
        playerManager.onStateChange = { [weak srv] in
            srv?.broadcastPlaybackUpdate()
        }
        playerManager.onPlaybackError = { [weak srv] message in
            srv?.broadcastError(message)
        }
        srv.start()
    }
}
