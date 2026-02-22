import SwiftUI
import UIKit

// MARK: - VLCPlayerView

/// UIViewControllerRepresentable wrapping VLCMediaPlayer for tvOS.
/// Handles Siri Remote gestures: center tap (play/pause), swipe (seek), menu (stop).
struct VLCPlayerView: UIViewControllerRepresentable {
    let playerManager: PlayerManager

    func makeUIViewController(context: Context) -> VLCPlayerViewController {
        let vc = VLCPlayerViewController()
        vc.playerManager = playerManager
        return vc
    }

    func updateUIViewController(_ uiViewController: VLCPlayerViewController, context: Context) {
        // PlayerManager drives all state; nothing to push here.
    }
}

// MARK: - VLCPlayerViewController

/// Hosts VLCMediaPlayer's drawable view and overlays a minimal time HUD.
class VLCPlayerViewController: UIViewController {

    var playerManager: PlayerManager!

    private let timeLabel = UILabel()
    private var hudTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // VLC renders into this view via playerManager.vlcPlayer.drawable
        if let vlc = playerManager.vlcPlayer {
            vlc.drawable = view
        }

        setupHUD()
        setupGestures()
    }

    // MARK: - HUD

    private func setupHUD() {
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .medium)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center
        timeLabel.alpha = 0
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 12
        blur.clipsToBounds = true

        blur.contentView.addSubview(timeLabel)
        view.addSubview(blur)

        NSLayoutConstraint.activate([
            blur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            blur.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blur.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            blur.heightAnchor.constraint(equalToConstant: 52),
            timeLabel.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 20),
            timeLabel.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -20),
            timeLabel.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
        ])

        // Periodically update the time label
        hudTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimeLabel()
        }
    }

    private func updateTimeLabel() {
        let current = playerManager.currentTime
        let total = playerManager.duration
        timeLabel.text = "\(formatTime(current)) / \(formatTime(total))"
    }

    private func showHUD() {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: reduceMotion ? 0 : 0.25) {
            self.timeLabel.superview?.superview?.alpha = 1
        }
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            UIView.animate(withDuration: reduceMotion ? 0 : 0.25) {
                self?.timeLabel.superview?.superview?.alpha = 0
            }
        }
    }

    // MARK: - Gestures

    private func setupGestures() {
        // Tap center: play/pause toggle
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        view.addGestureRecognizer(tap)

        // Swipe left: seek -10s
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        // Swipe right: seek +10s
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        // Menu button: stop playback
        let menu = UITapGestureRecognizer(target: self, action: #selector(handleMenu))
        menu.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menu)
    }

    @objc private func handleTap() {
        Task { @MainActor in
            if playerManager.playbackState == .playing {
                playerManager.pause()
            } else {
                playerManager.resume()
            }
            showHUD()
        }
    }

    @objc private func handleSwipeLeft() {
        Task { @MainActor in
            let target = max(0, playerManager.currentTime - 10)
            playerManager.seek(to: target)
            showHUD()
        }
    }

    @objc private func handleSwipeRight() {
        Task { @MainActor in
            let target = playerManager.currentTime + 10
            playerManager.seek(to: target)
            showHUD()
        }
    }

    @objc private func handleMenu() {
        Task { @MainActor in
            playerManager.stop()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    deinit {
        hudTimer?.invalidate()
    }
}
