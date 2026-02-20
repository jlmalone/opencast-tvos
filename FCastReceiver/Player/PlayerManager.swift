import AVFoundation
import AVKit
import Observation

// MARK: - PlayerManager

/// Wraps AVPlayer and tracks playback state for the FCast receiver.
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
    var errorMessage: String?

    // MARK: - AVPlayer

    let avPlayer = AVPlayer()

    // MARK: - Internal

    nonisolated(unsafe) private var timeObserver: Any?
    nonisolated(unsafe) private var statusObservation: NSKeyValueObservation?

    /// Called on any state/position change so FCastServer can broadcast updates.
    var onStateChange: (() -> Void)?
    /// Called when AVPlayer reports a load failure, so FCastServer can send PlaybackError.
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
                guard let self else { return }
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

    // MARK: - Playback Commands

    func play(message: PlayMessage) {
        guard let url = URL(string: message.url) else {
            let msg = "Invalid URL: \(message.url)"
            errorMessage = msg
            onPlaybackError?(msg)
            return
        }

        let asset: AVURLAsset
        if let msgHeaders = message.headers, !msgHeaders.isEmpty {
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": msgHeaders])
        } else {
            asset = AVURLAsset(url: url)
        }

        let item = AVPlayerItem(asset: asset)

        // Observe load errors. On failure:
        // - Report the error to the sender via onPlaybackError (→ PlaybackError opcode)
        // - Keep isPresenting = true so the player view stays visible and shows AVKit's
        //   own error UI. Only Stop (from sender) returns to the idle screen.
        //   This prevents the "flash then disappear" caused by instantly dismissing
        //   on any load failure (e.g. unsupported format like WebM or PNG).
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if item.status == .failed {
                    let msg = item.error?.localizedDescription ?? "Playback failed"
                    print("[PlayerManager] AVPlayer error: \(msg)")
                    self.errorMessage = msg
                    self.playbackState = .idle
                    // Do NOT set isPresenting = false here.
                    // Let the player view stay and show the error, so the screen
                    // doesn't flicker back to idle on every unsupported-format attempt.
                    // The sender receives PlaybackError and can decide to stop.
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
        errorMessage = nil
        onStateChange?()
    }

    func pause() {
        avPlayer.pause()
        playbackState = .paused
        onStateChange?()
    }

    func resume() {
        avPlayer.play()
        playbackState = .playing
        onStateChange?()
    }

    func stop() {
        statusObservation = nil
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        playbackState = .idle
        currentTime = 0
        duration = 0
        isPresenting = false
        errorMessage = nil
        onStateChange?()
    }

    func seek(to seconds: Double) {
        avPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func setVolume(_ vol: Double) {
        volume = max(0, min(1, vol))
        avPlayer.volume = Float(volume)
    }

    func setSpeed(_ spd: Double) {
        speed = spd
        if playbackState == .playing {
            avPlayer.rate = Float(spd)
        }
    }
}
