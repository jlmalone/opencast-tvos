import Foundation

// MARK: - Opcodes

enum Opcode: UInt8 {
    case none = 0
    case play = 1
    case pause = 2
    case resume = 3
    case stop = 4
    case seek = 5
    case playbackUpdate = 6
    case volumeUpdate = 7
    case setVolume = 8
    case playbackError = 9
    case setSpeed = 10
    case version = 11
    case ping = 12
    case pong = 13
    case initial = 14
    case playUpdate = 15
    case setPlaylistItem = 16
    case subscribeEvent = 17
    case unsubscribeEvent = 18
    case event = 19
}

// MARK: - Playback State

enum PlaybackState: Int, Codable {
    case idle = 0
    case playing = 1
    case paused = 2
}

// MARK: - Sender → Receiver Messages

struct PlayMessage: Codable {
    var container: String?
    var url: String
    var content: String?
    var time: Double?
    var volume: Double?
    var speed: Double?
    var headers: [String: String]?
}

struct SeekMessage: Codable {
    var time: Double
}

struct SetVolumeMessage: Codable {
    var volume: Double
}

struct SetSpeedMessage: Codable {
    var speed: Double
}

struct SetPlaylistItemMessage: Codable {
    var itemIndex: Int
}

struct PlayUpdateMessage: Codable {
    var items: [PlayMessage]
}

struct VersionMessage: Codable {
    var version: Int
}

struct InitialSenderMessage: Codable {
    var displayName: String
    var appName: String
    var appVersion: String
}

// MARK: - Receiver → Sender Messages

struct PlaybackUpdateMessage: Codable {
    var generationTime: Double
    var state: PlaybackState
    var time: Double
    var duration: Double
    var speed: Double
    var itemIndex: Int?
}

struct VolumeUpdateMessage: Codable {
    var generationTime: Double
    var volume: Double
}

struct PlaybackErrorMessage: Codable {
    var message: String
}

struct InitialReceiverMessage: Codable {
    var displayName: String
    var appName: String = "OpenCast tvOS"
    var appVersion: String = "1.4.0"
    var playData: PlayMessage? = nil
    var experimentalCapabilities: ReceiverCapabilities? = nil
}

// MARK: - Experimental Capabilities (WHEP / Screen Mirroring)

struct ReceiverCapabilities: Codable {
    var av: AVCapabilities?
}

struct AVCapabilities: Codable {
    var livestream: LivestreamCapabilities?
}

struct LivestreamCapabilities: Codable {
    var whep: Bool?
}
