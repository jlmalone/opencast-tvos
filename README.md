# FCast Receiver for Apple TV

A native tvOS app that turns any Apple TV into an FCast receiver. Cast video and audio from [Grayjay](https://grayjay.app), the [FCast desktop app](https://fcast.org), or any FCast-compatible sender — no Apple account, no AirPlay, no subscription required.

This is a community implementation of the open [FCast protocol](https://fcast.org) by FUTO.

---

## Features

- **Full FCast protocol v3** over TCP on port 46899
- **Automatic discovery** via Bonjour/mDNS (`_fcast._tcp`) — Apple TV appears in sender apps without any configuration
- **Native playback** via `AVPlayer` + `AVPlayerViewController` with the standard tvOS playback HUD
- **Custom HTTP headers** for auth-gated or DRM-protected streams
- **Idle screen** showing device name, IP address, and a QR code for easy sender pairing
- **Real-time state reporting** — position, duration, speed, and volume are continuously reported back to the sender
- **Full transport control** — play, pause, resume, stop, seek, set volume, set speed
- **Error feedback** — unsupported formats (MKV, WebM, DASH) are rejected immediately with a clear on-screen banner and a `PlaybackError` sent back to the sender

---

## Requirements

- Xcode 16+ with the tvOS 17.0 SDK
- Apple Developer Program membership (required for the Multicast Networking entitlement)
- Apple TV (4th generation or later) running tvOS 17.0+

---

## Quick Start

### 1. Clone

```bash
git clone https://github.com/jlmalone/fcast-appletv.git
cd fcast-appletv
```

### 2. Open in Xcode

```bash
open FCastReceiver.xcodeproj
```

### 3. Configure signing

- Select the `FCastReceiver` target → **Signing & Capabilities**
- Choose your development team
- Change the Bundle Identifier if needed (default: `tv.fcast.receiver`)

### 4. Add the Multicast Networking capability

In **Signing & Capabilities**, click `+` and search for **Multicast Networking**. This entitlement is required for Bonjour/mDNS advertisement so sender apps can discover the Apple TV automatically.

> **Note:** For App Store distribution, `com.apple.developer.networking.multicast` requires explicit approval from Apple. For development and TestFlight, it works with any paid developer account.

### 5. Build and run

Select your Apple TV as the target device and press Run. The idle screen will appear showing the device name, local IP address, and a QR code.

---

## Usage

Once the app is running on your Apple TV:

1. Open a FCast-compatible sender app on your phone, tablet, or desktop
2. Tap the cast icon — your Apple TV should appear automatically via mDNS
3. Select a video or audio stream to cast

**Compatible senders:**
- [FCast Desktop](https://fcast.org) (Windows / macOS / Linux) — auto-discovers via mDNS
- Any app implementing FCast protocol v3

---

## Project Structure

```
FCastReceiver/
├── FCastReceiverApp.swift       # @main App entry point; wires FCastServer to PlayerManager
├── Protocol/
│   ├── FCastPackets.swift       # Opcode enum and all Codable message structs
│   ├── FCastSession.swift       # Per-connection TCP framing: binary parser + frame sender
│   └── FCastServer.swift        # NWListener TCP server, Bonjour advertisement, message dispatch
├── Player/
│   └── PlayerManager.swift      # AVPlayer wrapper; @Observable state (play/pause/seek/volume/speed)
├── UI/
│   ├── ContentView.swift        # Root view; switches between IdleView and PlayerView; error banner
│   ├── IdleView.swift           # Waiting screen: device name, IP address, QR code
│   └── PlayerView.swift         # UIViewControllerRepresentable wrapping AVPlayerViewController
└── Utilities/
    └── NetworkHelper.swift      # Local IPv4 address detection; QR code generation via CoreImage
```

---

## Protocol Reference

### Binary Frame Format

All FCast messages use a simple length-prefixed binary framing over TCP:

```
┌─────────────────────┬──────────┬───────────────────────┐
│  4 bytes (uint32 LE) │  1 byte  │  N bytes              │
│  length             │  opcode  │  UTF-8 JSON body       │
└─────────────────────┴──────────┴───────────────────────┘
```

`length` = 1 (opcode byte) + body length. Body is omitted for Pause, Resume, Stop, Ping, and Pong.

### Opcodes

| Value | Name | Direction | Body |
|---|---|---|---|
| 1 | Play | Sender → Receiver | `PlayMessage` |
| 2 | Pause | Sender → Receiver | — |
| 3 | Resume | Sender → Receiver | — |
| 4 | Stop | Sender → Receiver | — |
| 5 | Seek | Sender → Receiver | `SeekMessage` |
| 6 | PlaybackUpdate | Receiver → Sender | `PlaybackUpdateMessage` |
| 7 | VolumeUpdate | Receiver → Sender | `VolumeUpdateMessage` |
| 8 | SetVolume | Sender → Receiver | `SetVolumeMessage` |
| 9 | PlaybackError | Receiver → Sender | `PlaybackErrorMessage` |
| 10 | SetSpeed | Sender → Receiver | `SetSpeedMessage` |
| 11 | Version | Both | `VersionMessage` |
| 12 | Ping | Sender → Receiver | — |
| 13 | Pong | Receiver → Sender | — |
| 14 | Initial | Both | `InitialMessage` |

### Connection Handshake

```
Sender  →  Receiver:  Version  { version: 3 }
Receiver →  Sender:   Version  { version: 3 }
Sender  →  Receiver:  Initial  { displayName, appName, appVersion }
Receiver →  Sender:   Initial  { displayName, appName, appVersion }

# Normal playback flow:
Sender  →  Receiver:  Play     { url, container?, time?, volume?, speed?, headers? }
Receiver →  Sender:   PlaybackUpdate  { state, time, duration, speed }  ← every 500 ms
Sender  →  Receiver:  Ping
Receiver →  Sender:   Pong
```

### Supported Formats

| Format | Support |
|---|---|
| HLS (`.m3u8`) | ✅ Best compatibility — recommended |
| MP4 / MOV / M4V | ✅ |
| MP3 / AAC / FLAC (audio) | ✅ |
| MPEG-DASH (`.mpd`) | ❌ Not supported by tvOS AVPlayer |
| MKV / WebM / AVI | ❌ Not supported by tvOS AVPlayer |

Unsupported formats are detected early (before AVPlayer attempts to load them) and result in an on-screen error banner and a `PlaybackError` message sent back to the sender.

---

## App Icons

The repository includes app icons generated from the official FCast brand assets (dark navy background, FCast logo centered). Icons are located in:

```
FCastReceiver/Assets.xcassets/App Icon & Top Shelf Image.brandassets/
```

tvOS uses a layered parallax icon format (`brandassets` + `imagestack`). Included sizes:

| Slot | Size |
|---|---|
| App Icon @1x | 400×240 |
| App Icon @2x | 800×480 |
| App Icon (App Store) | 1280×768 |
| Top Shelf Image | 1920×720 |
| Top Shelf Image Wide | 2320×720 |

To use custom icons, replace the PNG files inside each `Content.imageset` folder. The `Contents.json` structure must remain intact.

---

## Entitlements

| Entitlement | Purpose |
|---|---|
| `com.apple.developer.networking.multicast` | Bonjour/mDNS advertisement so senders auto-discover the Apple TV |
| `com.apple.security.network.server` | TCP listener on port 46899 |
| `com.apple.security.network.client` | Outbound connections for fetching stream URLs |

---

## Testing

### Manual test with Python

```python
import socket, json, struct, time

def send_frame(sock, opcode, payload=None):
    body = json.dumps(payload).encode() if payload else b''
    frame = struct.pack('<IB', 1 + len(body), opcode) + body
    sock.sendall(frame)

s = socket.create_connection(('YOUR_APPLETV_IP', 46899))
send_frame(s, 11, {'version': 3})          # Version handshake
time.sleep(0.1)
send_frame(s, 14, {'displayName': 'Test', 'appName': 'Test', 'appVersion': '1.0'})
time.sleep(0.1)
send_frame(s, 1, {'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'})
time.sleep(30)
s.close()
```

### Verify mDNS advertisement (macOS)

```bash
dns-sd -B _fcast._tcp local
```

Your Apple TV should appear within a few seconds of launching the app.

---

## Architecture Notes

### Why `@Observable` + a separate `ContentView`

SwiftUI's `@Observable` macro tracks property access inside `View.body`. It does **not** trigger updates from `App.body` (`WindowGroup`). The app wraps everything in `ContentView` — a proper `View` struct — so that `playerManager.isPresenting` changes correctly drive UI transitions.

### Data framing pitfall

`Data.removeFirst(n)` advances `startIndex` without resetting it to zero. Subscripting `data[0]` after a `removeFirst` will crash with an out-of-bounds error. `FCastSession` works around this by using `Data(buffer.dropFirst(n))` (which creates a new `Data` with `startIndex == 0`) and reads length bytes relative to `buffer.startIndex`.

### QR code rendering

`UIImage(ciImage:)` creates a lazy wrapper that SwiftUI cannot render — it displays as a blank image. `NetworkHelper.generateQRCode` uses `CIContext.createCGImage(_:from:)` to produce a concrete bitmap-backed `UIImage(cgImage:)`.

---

## Roadmap

### Broader format support via TVVLCKit

AVPlayer on tvOS only supports HLS, MP4/MOV, and a subset of audio formats. Many FCast senders cast MKV, WebM, AVI, and HEVC content that AVPlayer silently rejects. Integrating [TVVLCKit](https://code.videolan.org/videolan/VLCKit) would add support for virtually all container and codec combinations:

- MKV (Matroska), WebM (VP8/VP9/AV1), AVI, FLV, TS, and more
- HEVC/H.265, AV1, and other modern codecs
- Embedded subtitles (SRT, SSA/ASS, PGS)
- Multi-audio track selection

**Trade-offs:** TVVLCKit adds ~120 MB to the app binary, replaces the native tvOS playback HUD with a custom UI, and is licensed under LGPL. For App Store distribution, LGPL requires either dynamic linking or making the compiled object files available.

**Implementation sketch:**
1. Add TVVLCKit via CocoaPods or Swift Package Manager
2. Create a `VLCPlayerManager` mirroring the existing `PlayerManager` API
3. Wrap `VLCMediaPlayer` in a `UIViewControllerRepresentable` for SwiftUI
4. Fall back to AVPlayer for HLS (TVVLCKit HLS support is less mature)
5. Route unsupported MIME types through VLC before surfacing a `PlaybackError`

### Screen share / test pattern support

FCast Sender's **test pattern** sends a static PNG image (`container: "image/png"`) and its **screen share** feature streams WebM video. Both are currently rejected because AVPlayer cannot decode them.

Fixes:
- **Test pattern (PNG):** Detect `image/*` containers before passing to AVPlayer; display with SwiftUI `AsyncImage` or `UIImageView` instead
- **Screen share (WebM):** Requires either TVVLCKit (for WebM decoding) or a WebRTC library. WebM screen share at low latency via WebRTC is a larger undertaking and likely a separate integration

### Other planned improvements

- Playlist support (`SetPlaylistItem` opcode)
- Subtitle track selection
- Background audio playback (audio-only streams continue when app is backgrounded)
- Event subscription (`SubscribeEvent` / `UnsubscribeEvent` opcodes)

---

## Credits

### FCast Protocol — FUTO

The [FCast protocol](https://fcast.org) is designed and maintained by **[FUTO](https://futo.org)**, a company focused on developing technology that gives control back to users.

> FCast is an open casting protocol that allows you to stream media from any sender to any receiver, without being locked into a specific ecosystem.

- **Protocol specification:** [fcast.org](https://fcast.org)
- **Reference implementations:** [github.com/futo-org/fcast](https://github.com/futo-org/fcast)
- **FUTO website:** [futo.org](https://futo.org)

This project is an independent community implementation of the FCast protocol for tvOS. It is not affiliated with or endorsed by FUTO.

### Open Source

This app is built entirely on Apple's open frameworks — SwiftUI, AVFoundation, AVKit, Network.framework, and CoreImage — with no third-party dependencies.

---

## License

MIT — same license as the FCast protocol itself. See [futo-org/fcast](https://github.com/futo-org/fcast) for the official protocol specification.
