import Foundation
import Network
import UIKit

// MARK: - FCastServer

/// TCP server on port 46899 with Bonjour advertisement (_fcast._tcp).
/// Manages all active FCastSession connections and dispatches commands to PlayerManager.
@MainActor
class FCastServer {

    static let port: UInt16 = 46899

    private var listener: NWListener?
    private var sessions: [ObjectIdentifier: FCastSession] = [:]
    private let playerManager: PlayerManager

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager
    }

    // MARK: - Lifecycle

    func start() {
        let params = NWParameters.tcp
        params.includePeerToPeer = true

        guard let nwPort = NWEndpoint.Port(rawValue: Self.port),
              let listener = try? NWListener(using: params, on: nwPort) else {
            print("FCastServer: failed to create listener on port \(Self.port)")
            return
        }

        listener.service = NWListener.Service(
            name: UIDevice.current.name,
            type: "_fcast._tcp"
        )

        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.handleNewConnection(connection)
            }
        }

        listener.stateUpdateHandler = { state in
            print("FCastServer listener: \(state)")
        }

        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
        print("FCastServer started on port \(Self.port)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
        sessions.values.forEach { $0.cancel() }
        sessions.removeAll()
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        print("[FCastServer] New connection from \(connection.endpoint)")
        let session = FCastSession(connection: connection)
        session.delegate = self
        sessions[ObjectIdentifier(session)] = session
        session.start()
        // Receiver waits for sender to initiate Version handshake
    }

    // MARK: - Broadcast

    func broadcastPlaybackUpdate() {
        let msg = PlaybackUpdateMessage(
            generationTime: Date().timeIntervalSince1970 * 1000,
            state: playerManager.playbackState,
            time: playerManager.currentTime,
            duration: playerManager.duration,
            speed: playerManager.speed
        )
        sessions.values.forEach { $0.send(.playbackUpdate, msg) }
    }

    func broadcastVolumeUpdate() {
        let msg = VolumeUpdateMessage(
            generationTime: Date().timeIntervalSince1970 * 1000,
            volume: playerManager.volume
        )
        sessions.values.forEach { $0.send(.volumeUpdate, msg) }
    }

    func broadcastError(_ message: String) {
        let msg = PlaybackErrorMessage(message: message)
        sessions.values.forEach { $0.send(.playbackError, msg) }
    }

    // MARK: - Message Dispatch

    private func handleMessage(session: FCastSession, opcode: Opcode, data: Data?) {
        switch opcode {
        case .version:
            // Respond with our version
            session.send(.version, VersionMessage(version: 3))

        case .initial:
            let reply = InitialReceiverMessage(
                displayName: UIDevice.current.name,
                experimentalCapabilities: ReceiverCapabilities(
                    av: AVCapabilities(
                        livestream: LivestreamCapabilities(whep: true)
                    )
                )
            )
            session.send(.initial, reply)

        case .ping:
            session.send(.pong)

        case .play:
            guard let data, let msg = try? JSONDecoder().decode(PlayMessage.self, from: data) else {
                broadcastError("Invalid play message")
                return
            }
            playerManager.play(message: msg)

        case .pause:
            playerManager.pause()

        case .resume:
            playerManager.resume()

        case .stop:
            playerManager.stop()

        case .seek:
            guard let data, let msg = try? JSONDecoder().decode(SeekMessage.self, from: data) else { return }
            playerManager.seek(to: msg.time)

        case .setVolume:
            guard let data, let msg = try? JSONDecoder().decode(SetVolumeMessage.self, from: data) else { return }
            playerManager.setVolume(msg.volume)
            broadcastVolumeUpdate()

        case .setSpeed:
            guard let data, let msg = try? JSONDecoder().decode(SetSpeedMessage.self, from: data) else { return }
            playerManager.setSpeed(msg.speed)

        case .setPlaylistItem:
            guard let data, let msg = try? JSONDecoder().decode(SetPlaylistItemMessage.self, from: data) else {
                broadcastError("Invalid playlist item message")
                return
            }
            playerManager.setPlaylistItem(index: msg.itemIndex)

        case .playUpdate:
            // Sender is updating the playlist contents
            guard let data, let msg = try? JSONDecoder().decode(PlayUpdateMessage.self, from: data) else {
                broadcastError("Invalid play update message")
                return
            }
            playerManager.playlist = msg.items

        default:
            break
        }
    }
}

// MARK: - FCastSessionDelegate

extension FCastServer: FCastSessionDelegate {
    nonisolated func session(_ session: FCastSession, didReceive opcode: Opcode, data: Data?) {
        Task { @MainActor [weak self] in
            self?.handleMessage(session: session, opcode: opcode, data: data)
        }
    }

    nonisolated func sessionDidDisconnect(_ session: FCastSession) {
        Task { @MainActor [weak self] in
            self?.sessions.removeValue(forKey: ObjectIdentifier(session))
        }
    }
}
