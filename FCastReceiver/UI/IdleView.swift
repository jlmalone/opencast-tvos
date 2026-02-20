import SwiftUI
import UIKit

// MARK: - IdleView

/// Shown when no media is playing. Displays connection info and a QR code.
struct IdleView: View {
    let deviceName: String
    let ipAddress: String
    let port: UInt16

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

                        VStack(alignment: .leading, spacing: 4) {
                            Text("FCast Receiver")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.white)
                            Text("for Apple TV")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }

                    // Device name
                    Text(deviceName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

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
                            .foregroundColor(Color.white.opacity(0.4))
                    }

                    Spacer()

                    // About link — fine print at the bottom of the left column
                    Button {
                        showAbout = true
                    } label: {
                        Text("About")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showAbout) {
                        AboutView()
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
                    }
                }
            }
            .padding(80)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    IdleView(
        deviceName: "Living Room Apple TV",
        ipAddress: "192.168.1.42",
        port: 46899
    )
}
#endif
