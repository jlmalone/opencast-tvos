import SwiftUI
import UIKit

// MARK: - IdleView

/// Shown when no media is playing. Displays connection info and a QR code.
struct IdleView: View {
    let deviceName: String
    let ipAddress: String
    let port: UInt16
    var onPlaySample: (() -> Void)?

    @State private var showAbout = false

    private var connectionInfo: String {
        ipAddress.isEmpty ? "Connecting…" : "\(ipAddress):\(port)"
    }

    private var qrString: String {
        "fcast://\(ipAddress):\(port)"
    }

    private var qrImage: UIImage? {
        guard !ipAddress.isEmpty else { return nil }
        return NetworkHelper.generateQRCode(from: qrString)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 80) {
                // Left column: branding + connection info
                VStack(alignment: .leading, spacing: 28) {
                    Spacer()

                    // Icon + title
                    HStack(spacing: 20) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("FCast Receiver")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.white)
                            Text("for Apple TV")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("FCast Receiver for Apple TV")

                    // Device name
                    Text(deviceName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.vertical, 4)

                    // Connection details
                    VStack(alignment: .leading, spacing: 12) {
                        Label(connectionInfo, systemImage: "network")
                            .font(.system(size: 22, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))

                        Label("Waiting for FCast sender…", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)

                        Text("Use any FCast-compatible app to cast")
                            .font(.system(size: 17))
                            .foregroundColor(Color.white.opacity(0.6))
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 24) {
                        Button {
                            onPlaySample?()
                        } label: {
                            Label("Play Sample", systemImage: "play.circle")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .buttonStyle(IdleActionStyle())

                        Button {
                            showAbout = true
                        } label: {
                            Text("About")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(AboutLinkStyle())
                        .sheet(isPresented: $showAbout) {
                            AboutView()
                        }
                    }
                }

                // Right column: QR code
                VStack(spacing: 16) {
                    if let img = qrImage {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 260, height: 260)
                            .background(Color.white)
                            .cornerRadius(16)
                            .accessibilityLabel("QR code to connect")
                            .accessibilityHint("Scan with a sender app to connect to \(connectionInfo)")

                        Text("Scan to connect")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 260, height: 260)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white.opacity(0.3))
                            )
                            .accessibilityLabel("Loading connection QR code")
                    }
                }
            }
            .padding(80)
        }
    }
}

// MARK: - Idle Action Button Style

/// Prominent button style for primary idle screen actions.
private struct IdleActionStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isFocused ? .black : .white.opacity(0.85))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isFocused ? Color.white : Color.white.opacity(0.12))
            )
            .scaleEffect(reduceMotion ? 1.0 : (isFocused ? 1.05 : 1.0))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - About Link Button Style

/// Subtle fine-print link that shows a proper focus state on tvOS.
private struct AboutLinkStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isFocused ? .black : .white.opacity(0.6))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? Color.white : Color.clear)
            )
            .scaleEffect(reduceMotion ? 1.0 : (isFocused ? 1.08 : 1.0))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    IdleView(
        deviceName: "Living Room Apple TV",
        ipAddress: "192.168.1.42",
        port: 46899,
        onPlaySample: {}
    )
}
#endif
