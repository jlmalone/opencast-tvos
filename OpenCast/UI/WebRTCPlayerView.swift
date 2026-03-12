import SwiftUI
import UIKit
import WebRTC

// MARK: - WebRTCPlayerView

/// Displays a WebRTC video track received via WHEP (screen mirroring).
/// Menu button stops playback and returns to idle.
struct WebRTCPlayerView: UIViewControllerRepresentable {
    let playerManager: PlayerManager

    func makeUIViewController(context: Context) -> WebRTCPlayerViewController {
        let vc = WebRTCPlayerViewController()
        vc.playerManager = playerManager
        return vc
    }

    func updateUIViewController(_ uiViewController: WebRTCPlayerViewController, context: Context) {}
}

// MARK: - WebRTCPlayerViewController

class WebRTCPlayerViewController: UIViewController {

    var playerManager: PlayerManager!

    private let renderView = RTCMTLVideoView()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Video render view (Metal-based, works on Apple Silicon simulators and devices)
        renderView.translatesAutoresizingMaskIntoConstraints = false
        renderView.videoContentMode = .scaleAspectFit
        view.addSubview(renderView)

        NSLayoutConstraint.activate([
            renderView.topAnchor.constraint(equalTo: view.topAnchor),
            renderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Status label (shown while connecting)
        statusLabel.font = .systemFont(ofSize: 24, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.text = "Connecting to screen share..."
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        setupGestures()
        attachToWHEPClient()
    }

    private func attachToWHEPClient() {
        guard let whepClient = playerManager.whepClient else { return }

        let existingStateHandler = whepClient.onStateChange

        whepClient.onVideoTrack = { [weak self] track in
            guard let self else { return }
            self.addTrackToRenderer(track)
        }

        // Chain our UI updates onto PlayerManager's existing handler
        whepClient.onStateChange = { [weak self] state in
            existingStateHandler?(state)
            switch state {
            case .connected:
                self?.statusLabel.text = "Connected, waiting for video..."
            case .failed(let msg):
                self?.statusLabel.text = "Error: \(msg)"
                self?.statusLabel.isHidden = false
            case .idle:
                break
            case .connecting:
                self?.statusLabel.text = "Connecting to screen share..."
                self?.statusLabel.isHidden = false
            }
        }

        // If the video track arrived before this view loaded, pick it up now
        if let existingTrack = whepClient.videoTrack {
            print("[WebRTCPlayerView] Video track already available, attaching immediately")
            addTrackToRenderer(existingTrack)
        }
    }

    private func addTrackToRenderer(_ track: RTCVideoTrack) {
        print("[WebRTCPlayerView] Adding video track to Metal renderer")
        // Ensure layout is complete so the Metal view has a non-zero frame
        view.layoutIfNeeded()
        track.add(renderView)
        statusLabel.isHidden = true
    }

    private func setupGestures() {
        let menu = UITapGestureRecognizer(target: self, action: #selector(handleMenu))
        menu.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menu)
    }

    @objc private func handleMenu() {
        Task { @MainActor in
            playerManager.stop()
        }
    }
}
