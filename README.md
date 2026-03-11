# FCast Receiver for Apple TV

A native tvOS app that turns any Apple TV into an FCast receiver. Cast video and audio from [Grayjay](https://grayjay.app), the [FCast desktop app](https://fcast.org), or any FCast-compatible sender — no Apple account, no AirPlay, no subscription required.

This is a community implementation of the open [FCast protocol](https://fcast.org) by FUTO.

---

## Features

- **Full FCast protocol v3** over TCP on port 46899
- **Automatic discovery** via Bonjour/mDNS (`_fcast._tcp`) — Apple TV appears in sender apps without any configuration
- **Multi-backend playback** — AVPlayer (HLS, MP4, MOV, audio), TVVLCKit (MKV, WebM, AVI, HEVC, 100+ formats), WebRTC/WHEP (screen mirroring)
- **Image casting** — display PNG, JPEG, and other images fullscreen (test patterns, screenshots)
- **Custom HTTP headers** for auth-gated or DRM-protected streams
- **Playlist support** — opcodes 15 (playUpdate) and 16 (setPlaylistItem)
- **Idle screen** showing device name, IP address, QR code, and a "Play Sample" demo button
- **Real-time state reporting** — position, duration, speed, and volume are continuously reported back to the sender
- **Full transport control** — play, pause, resume, stop, seek, set volume, set speed via Siri Remote
- **Accessibility** — VoiceOver labels, Dynamic Type, Reduce Motion support
- **Error feedback** — playback failures shown with on-screen banner and `PlaybackError` sent back to the sender

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

### 2. Install dependencies

```bash
pod install
```

### 3. Open in Xcode

```bash
open FCastReceiver.xcworkspace
```

### 4. Configure signing

- Select the `FCastReceiver` target → **Signing & Capabilities**
- Choose your development team
- Change the Bundle Identifier if needed (default: `tv.fcast.receiver`)

### 5. Add the Multicast Networking capability

In **Signing & Capabilities**, click `+` and search for **Multicast Networking**. This entitlement is required for Bonjour/mDNS advertisement so sender apps can discover the Apple TV automatically.

> **Note:** For App Store distribution, `com.apple.developer.networking.multicast` requires explicit approval from Apple. For development and TestFlight, it works with any paid developer account.

### 6. Build and run

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
├── FCastReceiverApp.swift              # @main App entry point
├── FCastReceiver-Bridging-Header.h     # TVVLCKit Obj-C bridge
├── PrivacyInfo.xcprivacy               # App Store privacy manifest
├── Protocol/
│   ├── FCastPackets.swift              # Opcodes, message types, capabilities
│   ├── FCastSession.swift              # Per-connection TCP framing
│   └── FCastServer.swift               # TCP server + Bonjour + message dispatch
├── Player/
│   ├── PlayerManager.swift             # Multi-backend player (AVPlayer/VLC/WebRTC/Image)
│   └── WHEPClient.swift                # WebRTC WHEP client for screen mirroring
├── UI/
│   ├── AboutView.swift                 # Credits: FCast, FUTO, VLCKit attribution
│   ├── ContentView.swift               # Root view; switches idle/player; error banner
│   ├── IdleView.swift                  # Idle screen: connection info, QR, Play Sample
│   ├── PlayerView.swift                # AVPlayerViewController wrapper
│   ├── VLCPlayerView.swift             # VLC wrapper with Siri Remote controls
│   ├── WebRTCPlayerView.swift          # WebRTC video renderer
│   └── ImageDisplayView.swift          # Fullscreen image display
└── Utilities/
    └── NetworkHelper.swift             # Local IPv4 detection + QR code generation
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

| Format | Backend | Support |
|---|---|---|
| HLS (`.m3u8`) | AVPlayer | ✅ Best compatibility — recommended |
| MP4 / MOV / M4V | AVPlayer | ✅ |
| MP3 / AAC / FLAC (audio) | AVPlayer | ✅ |
| MKV / WebM / AVI / TS | TVVLCKit | ✅ |
| HEVC / H.265 / VP8 / VP9 | TVVLCKit | ✅ |
| PNG / JPEG / GIF (images) | AsyncImage | ✅ |
| WHEP screen mirroring | WebRTC | ✅ |
| MPEG-DASH (`.mpd`) | — | ❌ Not supported |

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
| `com.apple.security.network.server` | TCP listener on port 46899 |
| `com.apple.security.network.client` | Outbound connections for fetching stream URLs and WHEP SDP exchange |

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

### Completed

- ✅ TVVLCKit integration (MKV, WebM, AVI, HEVC, 100+ formats)
- ✅ Image casting (test patterns, screenshots)
- ✅ WebRTC/WHEP screen mirroring
- ✅ Playlist support (opcodes 15/16)
- ✅ Accessibility (VoiceOver, Reduce Motion)
- ✅ "Play Sample" demo mode for testing without a sender

### Planned

- Subtitle track selection
- Background audio playback (audio-only streams continue when app is backgrounded)
- Event subscription (`SubscribeEvent` / `UnsubscribeEvent` opcodes)
- Migrate TVVLCKit from CocoaPods to SPM (when available)

---

## Credits

### FCast Protocol — FUTO

The [FCast protocol](https://fcast.org) is designed and maintained by **[FUTO](https://futo.org)**, a company focused on developing technology that gives control back to users.

> FCast is an open casting protocol that allows you to stream media from any sender to any receiver, without being locked into a specific ecosystem.

- **Protocol specification:** [fcast.org](https://fcast.org)
- **Reference implementations:** [github.com/futo-org/fcast](https://github.com/futo-org/fcast)
- **FUTO website:** [futo.org](https://futo.org)

This project is an independent community implementation of the FCast protocol for tvOS. It is not affiliated with or endorsed by FUTO.

### Dependencies

- **[TVVLCKit](https://code.videolan.org/videolan/VLCKit)** (~> 3.6.0) — universal format playback (MKV, WebM, AVI, HEVC, 100+ formats). LGPL 2.1. Via CocoaPods.
- **[WebRTC](https://github.com/webrtc-sdk/Specs)** (137.7151.00) — WHEP/WebRTC screen mirroring. BSD 3-Clause. Via SPM.
- Apple frameworks: SwiftUI, AVFoundation, AVKit, Network.framework, CoreImage

---

## License

MIT — same license as the FCast protocol itself. See [futo-org/fcast](https://github.com/futo-org/fcast) for the official protocol specification.
