import AVFoundation
import AVKit
import Observation

// MARK: - Player Backend

enum PlayerBackend {
    case avPlayer    // HLS, MP4, MOV, audio
    case vlc         // MKV, WebM, AVI, HEVC, everything else
    case image       // PNG, JPEG, etc.
}

// MARK: - PlayerManager

/// Wraps AVPlayer + VLCMediaPlayer and tracks playback state for the FCast receiver.
/// Routes media to the correct backend based on container MIME type.
/// All methods must be called on the main actor.
@MainActor
@Observable
class PlayerManager {

    // MARK: - Observed State

    var playbackState: PlaybackState = .idle
    var currentTime: Double = 0
    var duration: Double = 0
    var volume: Double = 1.0
    var speed: Double = 1.0
    var isPresenting: Bool = false
    var activeBackend: PlayerBackend = .avPlayer
    /// Non-nil when the last play attempt failed. Shown in IdleView, auto-cleared after display.
    var lastError: String?

    // MARK: - Image State

    var imageURL: URL?

    // MARK: - Playlist

    var playlist: [PlayMessage] = []

    // MARK: - AVPlayer

    let avPlayer = AVPlayer()

    // MARK: - VLC

    var vlcPlayer: VLCMediaPlayer?

    // MARK: - Internal

    nonisolated(unsafe) private var timeObserver: Any?
    nonisolated(unsafe) private var statusObservation: NSKeyValueObservation?
    private var vlcDelegate: VLCDelegateProxy?

    /// Called on any state/position change so FCastServer can broadcast updates.
    var onStateChange: (() -> Void)?
    /// Called on AVPlayer load failure so FCastServer can send PlaybackError to sender.
    var onPlaybackError: ((String) -> Void)?

    // MARK: - Init / Deinit

    init() {
        setupTimeObserver()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    deinit {
        if let timeObserver {
            avPlayer.removeTimeObserver(timeObserver)
        }
    }

    // MARK: - Setup

    private func setupTimeObserver() {
        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.activeBackend == .avPlayer else { return }
                let seconds = time.seconds
                self.currentTime = seconds.isNaN || seconds.isInfinite ? 0 : seconds
                if let dur = self.avPlayer.currentItem?.duration, dur.isNumeric {
                    self.duration = dur.seconds
                }
                self.onStateChange?()
            }
        }
    }

    @objc private func playerItemDidEnd() {
        playbackState = .idle
        isPresenting = false
        onStateChange?()
    }

    // MARK: - Format Routing

    private func selectBackend(container: String?, url: URL) -> PlayerBackend {
        if let container {
            let lower = container.lowercased()

            // Images
            if lower.hasPrefix("image/") {
                return .image
            }

            // HLS is better on AVPlayer
            if lower == "application/x-mpegurl" || lower == "application/vnd.apple.mpegurl" {
                return .avPlayer
            }

            // Native AVPlayer formats
            if lower == "video/mp4" || lower == "video/quicktime" || lower.hasPrefix("audio/") {
                return .avPlayer
            }

            // Everything else (MKV, WebM, AVI, TS, etc.) goes to VLC
            return .vlc
        }

        // No MIME — check file extension
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m3u8":
            return .avPlayer
        case "mp4", "mov", "m4v", "m4a", "mp3", "aac", "wav":
            return .avPlayer
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "heic":
            return .image
        default:
            // MKV, WebM, AVI, TS, etc.
            return .vlc
        }
    }

    // MARK: - Playback Commands

    func play(message: PlayMessage) {
        guard let url = URL(string: message.url) else {
            let msg = "Invalid URL"
            lastError = msg
            onPlaybackError?(msg)
            return
        }

        // Stop any current playback first
        stopInternal()

        let backend = selectBackend(container: message.container, url: url)
        activeBackend = backend

        switch backend {
        case .avPlayer:
            playWithAVPlayer(url: url, message: message)
        case .vlc:
            playWithVLC(url: url, message: message)
        case .image:
            playImage(url: url)
        }
    }

    // MARK: - AVPlayer Backend

    private func playWithAVPlayer(url: URL, message: PlayMessage) {
        let asset: AVURLAsset
        if let msgHeaders = message.headers, !msgHeaders.isEmpty {
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": msgHeaders])
        } else {
            asset = AVURLAsset(url: url)
        }

        let item = AVPlayerItem(asset: asset)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if item.status == .failed {
                    let msg = item.error?.localizedDescription ?? "Playback failed"
                    print("[PlayerManager] AVPlayer error: \(msg)")
                    self.lastError = msg
                    self.playbackState = .idle
                    self.isPresenting = false
                    self.onPlaybackError?(msg)
                    self.onStateChange?()
                }
            }
        }

        avPlayer.replaceCurrentItem(with: item)

        if let startTime = message.time, startTime > 0 {
            avPlayer.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
        }
        if let vol = message.volume { setVolume(vol) }
        if let spd = message.speed { setSpeed(spd) }

        avPlayer.play()
        playbackState = .playing
        isPresenting = true
        lastError = nil
        onStateChange?()
    }

    // MARK: - VLC Backend

    private func playWithVLC(url: URL, message: PlayMessage) {
        let media = VLCMedia(url: url)

        // Pass HTTP headers via VLC media options
        if let headers = message.headers {
            if let ua = headers["User-Agent"] ?? headers["user-agent"] {
                media.addOption("--http-user-agent=\(ua)")
            }
            if let ref = headers["Referer"] ?? headers["referer"] {
                media.addOption("--http-referrer=\(ref)")
            }
        }

        let player = VLCMediaPlayer()
        player.media = media

        // Set up delegate proxy for VLC callbacks
        let proxy = VLCDelegateProxy(playerManager: self)
        player.delegate = proxy
        vlcDelegate = proxy

        vlcPlayer = player
        player.play()

        if let startTime = message.time, startTime > 0 {
            // VLC seek uses milliseconds for time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak player] in
                player?.time = VLCTime(int: Int32(startTime * 1000))
            }
        }
        if let vol = message.volume { setVolume(vol) }
        if let spd = message.speed { setSpeed(spd) }

        playbackState = .playing
        isPresenting = true
        lastError = nil
        onStateChange?()
    }

    // MARK: - Image Backend

    private func playImage(url: URL) {
        imageURL = url
        playbackState = .playing
        currentTime = 0
        duration = 0
        isPresenting = true
        lastError = nil
        onStateChange?()
    }

    // MARK: - Transport Controls

    func pause() {
        switch activeBackend {
        case .avPlayer:
            avPlayer.pause()
        case .vlc:
            vlcPlayer?.pause()
        case .image:
            break
        }
        playbackState = .paused
        onStateChange?()
    }

    func resume() {
        switch activeBackend {
        case .avPlayer:
            avPlayer.play()
        case .vlc:
            vlcPlayer?.play()
        case .image:
            break
        }
        playbackState = .playing
        onStateChange?()
    }

    func stop() {
        stopInternal()
        onStateChange?()
    }

    private func stopInternal() {
        switch activeBackend {
        case .avPlayer:
            statusObservation = nil
            avPlayer.pause()
            avPlayer.replaceCurrentItem(with: nil)
        case .vlc:
            vlcPlayer?.stop()
            vlcPlayer = nil
            vlcDelegate = nil
        case .image:
            imageURL = nil
        }
        playbackState = .idle
        currentTime = 0
        duration = 0
        isPresenting = false
        lastError = nil
    }

    func seek(to seconds: Double) {
        switch activeBackend {
        case .avPlayer:
            avPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        case .vlc:
            vlcPlayer?.time = VLCTime(int: Int32(seconds * 1000))
        case .image:
            break
        }
    }

    func setVolume(_ vol: Double) {
        volume = max(0, min(1, vol))
        switch activeBackend {
        case .avPlayer:
            avPlayer.volume = Float(volume)
        case .vlc:
            // VLC volume is 0-200, where 100 = normal
            vlcPlayer?.audio?.volume = Int32(volume * 100)
        case .image:
            break
        }
    }

    func setSpeed(_ spd: Double) {
        speed = spd
        if playbackState == .playing {
            switch activeBackend {
            case .avPlayer:
                avPlayer.rate = Float(spd)
            case .vlc:
                vlcPlayer?.rate = Float(spd)
            case .image:
                break
            }
        }
    }

    // MARK: - Playlist

    func setPlaylistItem(index: Int) {
        guard index >= 0 && index < playlist.count else {
            let msg = "Playlist index \(index) out of range (0..<\(playlist.count))"
            print("[PlayerManager] \(msg)")
            lastError = msg
            onPlaybackError?(msg)
            return
        }
        play(message: playlist[index])
    }

    // MARK: - VLC State Update (called from delegate proxy)

    func vlcStateDidChange() {
        guard activeBackend == .vlc, let vlc = vlcPlayer else { return }

        switch vlc.state {
        case .playing:
            playbackState = .playing
        case .paused:
            playbackState = .paused
        case .stopped, .ended, .error:
            if vlc.state == .error {
                let msg = "VLC playback error"
                print("[PlayerManager] \(msg)")
                lastError = msg
                onPlaybackError?(msg)
            }
            playbackState = .idle
            isPresenting = false
            vlcPlayer = nil
            vlcDelegate = nil
        default:
            break
        }
        onStateChange?()
    }

    func vlcTimeDidChange() {
        guard activeBackend == .vlc, let vlc = vlcPlayer else { return }
        let ms = vlc.time.intValue
        currentTime = Double(ms) / 1000.0

        if let media = vlc.media, media.length.intValue > 0 {
            duration = Double(media.length.intValue) / 1000.0
        }
        onStateChange?()
    }
}

// MARK: - VLC Delegate Proxy

/// Bridges VLCMediaPlayerDelegate (Obj-C) to our @MainActor PlayerManager.
class VLCDelegateProxy: NSObject, VLCMediaPlayerDelegate {

    private weak var playerManager: PlayerManager?

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor [weak self] in
            self?.playerManager?.vlcStateDidChange()
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor [weak self] in
            self?.playerManager?.vlcTimeDidChange()
        }
    }
}
