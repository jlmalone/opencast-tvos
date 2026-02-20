# FCast Receiver for Apple TV

A native tvOS app that receives casts from any FCast-compatible sender (Grayjay, FCast desktop, etc.). This is an open-source community implementation of the [FCast protocol](https://fcast.org) by FUTO.

## Features

- Full FCast protocol v3 support (TCP, port 46899)
- Bonjour/mDNS advertisement (`_fcast._tcp`) — Apple TV appears automatically in sender apps
- Native HLS/MP4/MOV playback via `AVPlayer` + `AVPlayerViewController`
- Custom HTTP headers support (for DRM/auth-gated streams)
- Idle screen with device name, IP address, and QR code for easy discovery
- Real-time playback state reporting back to sender (position, duration, speed, volume)
- Full transport control: play, pause, resume, stop, seek, set volume, set speed

## Requirements

- Xcode 15+ with tvOS 17.0 SDK
- Apple Developer Program membership (required for the Multicast Networking entitlement)
- Apple TV (4th gen or later) running tvOS 17.0+

## Quick Start

1. **Clone the repo:**
   ```bash
   git clone https://github.com/jlmalone/fcast-appletv.git
   cd fcast-appletv
   ```

2. **Open in Xcode:**
   ```bash
   open FCastReceiver.xcodeproj
   ```

3. **Configure signing:**
   - Select the `FCastReceiver` target → Signing & Capabilities
   - Choose your development team
   - Change the Bundle Identifier if needed (default: `tv.fcast.receiver`)

4. **Add the Multicast Networking capability:**
   - Signing & Capabilities → `+` → search "Multicast Networking"
   - This is needed for Bonjour advertisement

5. **Build & run** to your Apple TV

## Using with Senders

Once running, your Apple TV will appear in any FCast-compatible sender:

- **[Grayjay](https://grayjay.app)** — tap the cast icon, select your Apple TV
- **[FCast Desktop](https://fcast.org)** — sender will discover the TV via mDNS
- **Manual TCP** — connect to `<apple-tv-ip>:46899` using the FCast binary protocol

## Project Structure

```
FCastReceiver/
├── FCastReceiverApp.swift       # @main App entry, wires server + player
├── Protocol/
│   ├── FCastPackets.swift       # Opcode enum + all Codable message types
│   ├── FCastSession.swift       # Per-connection binary frame parser/sender
│   └── FCastServer.swift        # NWListener TCP server + Bonjour + dispatch
├── Player/
│   └── PlayerManager.swift      # AVPlayer wrapper, @Observable state
├── UI/
│   ├── IdleView.swift           # Waiting screen (device name, IP, QR code)
│   └── PlayerView.swift         # AVPlayerViewController SwiftUI wrapper
└── Utilities/
    └── NetworkHelper.swift      # Local IP detection + QR code generation
```

## Protocol Notes

### Binary Frame Format

```
[4 bytes: uint32 LE length][1 byte: opcode][N bytes: UTF-8 JSON body]
```

`length` = 1 (opcode byte) + body length. Body is absent for Pause, Resume, Stop, Ping, Pong.

### Connection Handshake

```
Sender → Receiver: Version { version: 3 }
Receiver → Sender: Version { version: 3 }
Sender → Receiver: Initial { displayName, appName, appVersion }
Receiver → Sender: Initial { displayName, appName, appVersion }
Sender → Receiver: Play { url, ... }
Receiver → Sender: PlaybackUpdate { state, time, duration, ... }  (every 500ms)
Sender → Receiver: Ping  (keepalive)
Receiver → Sender: Pong
```

### Supported Formats

Formats supported by tvOS AVPlayer:
- ✅ HLS (`.m3u8`) — best compatibility
- ✅ MP4 / MOV / M4V
- ✅ MP3 / AAC / FLAC (audio)
- ❌ MPEG-DASH (`.mpd`) — not natively supported on tvOS; sender receives `PlaybackError`

## App Icons

The repository ships without app icon images (to avoid including third-party branding). Add your icons to:

```
FCastReceiver/Assets.xcassets/AppIcon.appiconset/
```

Required sizes for tvOS:
- `400x240` @ 1x (primary app icon)
- `800x480` @ 2x (primary app icon)

You can download FCast brand assets from [github.com/futo-org/fcast](https://github.com/futo-org/fcast/tree/master/receivers/common/assets/icons).

## Entitlements

| Entitlement | Why |
|---|---|
| `com.apple.developer.networking.multicast` | Bonjour/mDNS advertisement for sender discovery |
| `com.apple.security.network.server` | TCP listener on port 46899 |
| `com.apple.security.network.client` | Outbound connections (for stream URLs) |

> Note: `com.apple.developer.networking.multicast` requires explicit approval from Apple for App Store distribution. For development/TestFlight sideloading, it works with a standard paid developer account.

## Testing

### Manual test with Python:

```python
import socket, json, struct, time

def send_frame(sock, opcode, payload=None):
    body = json.dumps(payload).encode() if payload else b''
    frame = struct.pack('<IB', 1 + len(body), opcode) + body
    sock.sendall(frame)

s = socket.create_connection(('YOUR_APPLETV_IP', 46899))
send_frame(s, 11, {'version': 3})   # Version
time.sleep(0.1)
send_frame(s, 14, {'displayName': 'Test', 'appName': 'Test', 'appVersion': '1.0'})  # Initial
time.sleep(0.1)
send_frame(s, 1, {'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'})  # Play
time.sleep(30)
```

### mDNS check (macOS):

```bash
dns-sd -B _fcast._tcp local
```

Your Apple TV should appear within a few seconds.

## License

MIT License — same as the FCast protocol itself. See [futo-org/fcast](https://github.com/futo-org/fcast) for the protocol specification.

## Related

- [FCast Protocol](https://fcast.org) by FUTO
- [futo-org/fcast](https://github.com/futo-org/fcast) — official reference implementations
- [Grayjay](https://grayjay.app) — primary FCast sender app
