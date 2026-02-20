import SwiftUI

// MARK: - AboutView

/// Full-screen about sheet accessible from the idle screen.
struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 36) {

                // MARK: Header row
                HStack(alignment: .center, spacing: 20) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("FCast Receiver for Apple TV")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Version \(appVersion)  ·  Community implementation  ·  Not affiliated with FUTO")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button("Done") { dismiss() }
                        .font(.system(size: 20, weight: .medium))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                }

                Divider().background(Color.white.opacity(0.12))

                // MARK: Two-column body
                HStack(alignment: .top, spacing: 80) {

                    // Left column: FCast Protocol
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "FCast Protocol", icon: "antenna.radiowaves.left.and.right")

                        Text("An open casting protocol that lets you stream media\nfrom any sender to any receiver — no ecosystem lock-in.")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.65))
                            .lineSpacing(4)
                            .padding(.bottom, 4)

                        CreditRow(label: "Designed & maintained by", value: "FUTO", detail: "futo.org")
                        CreditRow(label: "Protocol specification",   value: "fcast.org", detail: "Open specification, free to implement")
                        CreditRow(label: "Reference implementations", value: "github.com/futo-org/fcast", detail: "Android, iOS, Windows, macOS, Linux, web")
                        CreditRow(label: "Protocol version",         value: "v3", detail: "TCP port 46899 · binary length-prefixed framing")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Vertical divider
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1)

                    // Right column: FUTO + This Project
                    VStack(alignment: .leading, spacing: 24) {

                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "About FUTO", icon: "building.2")
                            Text("A company focused on developing technology that gives\ncontrol back to users.")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.65))
                                .lineSpacing(4)
                            CreditRow(label: "Website", value: "futo.org", detail: nil)
                        }

                        Divider().background(Color.white.opacity(0.10))

                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "This Project", icon: "chevron.left.forwardslash.chevron.right")
                            CreditRow(label: "Source code", value: "github.com/jlmalone/fcast-appletv", detail: "MIT License · open source")
                            CreditRow(label: "Built with",  value: "Swift · SwiftUI · AVFoundation · Network.framework", detail: "No third-party dependencies")
                            CreditRow(label: "License",     value: "MIT", detail: "Same license as the FCast protocol itself")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(80)
        }
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.white)
    }
}

private struct CreditRow: View {
    let label: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .kerning(0.8)
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            if let detail {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    AboutView()
}
#endif
