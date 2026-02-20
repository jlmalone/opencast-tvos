import Foundation
import UIKit
import CoreImage

// MARK: - NetworkHelper

struct NetworkHelper {

    /// Returns the device's primary local IPv4 address (non-loopback).
    static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING),
               addr.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let addrLen = socklen_t(ptr.pointee.ifa_addr.pointee.sa_len)
                if getnameinfo(ptr.pointee.ifa_addr, addrLen,
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    if ip != "127.0.0.1" {
                        address = ip
                        break
                    }
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return address
    }

    /// Generates a QR code UIImage from the given string.
    /// Uses CIContext to render to a CGImage-backed UIImage — required for
    /// SwiftUI Image(uiImage:) to display correctly (CIImage-backed UIImages render blank).
    static func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale: CGFloat = 12
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        // Must render through CIContext → CGImage; UIImage(ciImage:) is lazy and
        // SwiftUI cannot draw it — it renders as a blank/transparent image.
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
