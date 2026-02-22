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

    #if targetEnvironment(simulator)
    private let renderView = UIView()  // RTCMTLVideoView not available in simulator
    #else
    private let renderView = RTCMTLVideoView()
    #endif

    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Video render view
        renderView.translatesAutoresizingMaskIntoConstraints = false
        #if !targetEnvironment(simulator)
        renderView.videoContentMode = .scaleAspectFit
        #endif
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

        // Attach video track renderer
        if let whepClient = playerManager.whepClient {
            whepClient.onVideoTrack = { [weak self] track in
                guard let self else { return }
                #if !targetEnvironment(simulator)
                track.add(self.renderView)
                #endif
                self.statusLabel.isHidden = true
            }
            whepClient.onStateChange = { [weak self] state in
                switch state {
                case .connected:
                    self?.statusLabel.isHidden = true
                case .failed(let msg):
                    self?.statusLabel.text = "Error: \(msg)"
                    self?.statusLabel.isHidden = false
                default:
                    break
                }
            }
        }

        setupGestures()
    }

    private func setupGestures() {
        // Menu button: stop
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
