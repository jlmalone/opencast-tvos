import Foundation
import WebRTC

// MARK: - WHEPClient

/// Minimal WHEP (WebRTC-HTTP Egress Protocol) client.
/// Connects to a sender's WHEP endpoint, negotiates WebRTC via SDP over HTTP,
/// and receives VP8 video + Opus audio.
@MainActor
class WHEPClient: NSObject {

    // MARK: - State

    enum State {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    var state: State = .idle
    var onStateChange: ((State) -> Void)?
    var onVideoTrack: ((RTCVideoTrack) -> Void)?

    /// Stored so late-arriving views can pick up the track after the callback fires.
    private(set) var videoTrack: RTCVideoTrack?

    // MARK: - WebRTC

    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        return RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
    }()

    private var peerConnection: RTCPeerConnection?
    private var whepResourceURL: URL?

    // MARK: - Connect

    func connect(to whepURL: URL) {
        print("[WHEPClient] Connecting to \(whepURL)")
        state = .connecting
        onStateChange?(.connecting)

        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        guard let pc = Self.factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        ) else {
            let err = "Failed to create peer connection"
            state = .failed(err)
            onStateChange?(.failed(err))
            return
        }
        peerConnection = pc

        // Add receive-only transceivers for audio and video
        let videoInit = RTCRtpTransceiverInit()
        videoInit.direction = .recvOnly
        pc.addTransceiver(of: .video, init: videoInit)

        let audioInit = RTCRtpTransceiverInit()
        audioInit.direction = .recvOnly
        pc.addTransceiver(of: .audio, init: audioInit)

        // Create SDP offer
        let offerConstraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true",
            ],
            optionalConstraints: nil
        )

        pc.offer(for: offerConstraints) { [weak self] sdp, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    let err = "SDP offer failed: \(error.localizedDescription)"
                    self.state = .failed(err)
                    self.onStateChange?(.failed(err))
                    return
                }
                guard let sdp else { return }
                print("[WHEPClient] SDP offer created (\(sdp.sdp.count) bytes)")
                self.handleLocalSDP(sdp, whepURL: whepURL)
            }
        }
    }

    // MARK: - SDP Exchange

    private func handleLocalSDP(_ sdp: RTCSessionDescription, whepURL: URL) {
        // Set local description
        peerConnection?.setLocalDescription(sdp) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    let err = "Set local desc failed: \(error.localizedDescription)"
                    self.state = .failed(err)
                    self.onStateChange?(.failed(err))
                    return
                }
                print("[WHEPClient] Local description set, POSTing offer to WHEP endpoint")
                self.postOffer(sdp.sdp, to: whepURL)
            }
        }
    }

    private func postOffer(_ sdpString: String, to whepURL: URL) {
        var request = URLRequest(url: whepURL)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = sdpString.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    let err = "WHEP POST failed: \(error.localizedDescription)"
                    self.state = .failed(err)
                    self.onStateChange?(.failed(err))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    let err = "WHEP: invalid response"
                    self.state = .failed(err)
                    self.onStateChange?(.failed(err))
                    return
                }

                print("[WHEPClient] WHEP POST response: HTTP \(httpResponse.statusCode)")

                guard (200...299).contains(httpResponse.statusCode),
                      let data,
                      let answerSDP = String(data: data, encoding: .utf8) else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
                    let err = "WHEP: HTTP \(httpResponse.statusCode) — \(body)"
                    self.state = .failed(err)
                    self.onStateChange?(.failed(err))
                    return
                }

                // Store the resource URL for teardown (from Location header)
                if let location = httpResponse.value(forHTTPHeaderField: "Location") {
                    if let resourceURL = URL(string: location, relativeTo: whepURL) {
                        self.whepResourceURL = resourceURL
                    }
                }

                print("[WHEPClient] SDP answer received (\(answerSDP.count) bytes), setting remote description")

                // Set remote description from answer
                let answer = RTCSessionDescription(type: .answer, sdp: answerSDP)
                self.peerConnection?.setRemoteDescription(answer) { [weak self] error in
                    Task { @MainActor [weak self] in
                        if let error {
                            let err = "Set remote desc failed: \(error.localizedDescription)"
                            self?.state = .failed(err)
                            self?.onStateChange?(.failed(err))
                        }
                        // ICE candidates will be gathered and trickled automatically
                    }
                }
            }
        }.resume()
    }

    // MARK: - Disconnect

    func disconnect() {
        // Send DELETE to WHEP resource URL to signal teardown
        if let resourceURL = whepResourceURL {
            var request = URLRequest(url: resourceURL)
            request.httpMethod = "DELETE"
            URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
        }

        peerConnection?.close()
        peerConnection = nil
        whepResourceURL = nil
        videoTrack = nil
        state = .idle
        onStateChange?(.idle)
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WHEPClient: RTCPeerConnectionDelegate {

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("[WHEPClient] Signaling state: \(stateChanged.rawValue)")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Task { @MainActor [weak self] in
            if let videoTrack = stream.videoTracks.first {
                self?.videoTrack = videoTrack
                self?.onVideoTrack?(videoTrack)
            }
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch newState {
            case .connected, .completed:
                self.state = .connected
                self.onStateChange?(.connected)
            case .failed:
                let err = "ICE connection failed"
                self.state = .failed(err)
                self.onStateChange?(.failed(err))
            case .disconnected, .closed:
                self.state = .idle
                self.onStateChange?(.idle)
            default:
                break
            }
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("[WHEPClient] ICE gathering state: \(newState.rawValue)")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        // WHEP trickle ICE: PATCH the resource URL with candidates
        // For simplicity, we rely on the full SDP offer having candidates gathered
        // The sender's WHEP server typically handles ICE in the initial exchange
        print("[WHEPClient] ICE candidate: \(candidate.sdp)")
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        let trackKind = rtpReceiver.track?.kind ?? "unknown"
        print("[WHEPClient] RTP receiver added: \(trackKind)")
        Task { @MainActor [weak self] in
            if let videoTrack = rtpReceiver.track as? RTCVideoTrack {
                print("[WHEPClient] Video track received, notifying view")
                self?.videoTrack = videoTrack
                self?.onVideoTrack?(videoTrack)
            }
        }
    }
}
