import SwiftUI

// MARK: - AboutView

/// Full-screen about sheet accessible from the idle screen.
struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    // App version pulled from the bundle at runtime
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 48) {

                    // MARK: App header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 16) {
                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FCast Receiver for Apple TV")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Version \(appVersion)")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }
                        }

                        Text("An independent, open-source community implementation of the FCast protocol for tvOS. Not affiliated with or endorsed by FUTO.")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 4)
                    }

                    Divider().background(Color.white.opacity(0.12))

                    // MARK: FCast Protocol
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "FCast Protocol", icon: "antenna.radiowaves.left.and.right")

                        Text("FCast is an open casting protocol designed to let you stream media from any sender to any receiver, without lock-in to a specific ecosystem or platform.")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.75))

                        CreditRow(
                            label: "Designed & maintained by",
                            value: "FUTO",
                            detail: "futo.org"
                        )
                        CreditRow(
                            label: "Protocol specification",
                            value: "fcast.org",
                            detail: "Open specification, free to implement"
                        )
                        CreditRow(
                            label: "Reference implementations",
                            value: "github.com/futo-org/fcast",
                            detail: "Android, iOS, Windows, macOS, Linux, web"
                        )
                        CreditRow(
                            label: "Protocol version",
                            value: "v3",
                            detail: "TCP port 46899 · binary length-prefixed framing"
                        )
                    }

                    Divider().background(Color.white.opacity(0.12))

                    // MARK: FUTO
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "About FUTO", icon: "building.2")

                        Text("FUTO is a company focused on developing technology that gives control back to users. They created FCast as a free and open alternative to proprietary casting protocols.")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.75))

                        CreditRow(label: "Website", value: "futo.org", detail: nil)
                    }

                    Divider().background(Color.white.opacity(0.12))

                    // MARK: This project
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "This Project", icon: "chevron.left.forwardslash.chevron.right")

                        CreditRow(
                            label: "Source code",
                            value: "github.com/jlmalone/fcast-appletv",
                            detail: "MIT License · open source"
                        )
                        CreditRow(
                            label: "Built with",
                            value: "Swift · SwiftUI · AVFoundation · Network.framework",
                            detail: "No third-party dependencies"
                        )
                        CreditRow(
                            label: "License",
                            value: "MIT",
                            detail: "Same license as the FCast protocol itself"
                        )
                    }

                    // MARK: Dismiss
                    HStack {
                        Spacer()
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 22, weight: .medium))
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                .padding(80)
            }
        }
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 26, weight: .semibold))
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .kerning(0.8)
            Text(value)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            if let detail {
                Text(detail)
                    .font(.system(size: 17))
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
