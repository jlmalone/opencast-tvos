# CLAUDE.md - OvrCast (FCast-compatible receiver for Apple TV)

## Overview
Native tvOS application implementing the FCast protocol v3 for receiving cast video/audio streams from Grayjay and FCast desktop senders. Built with SwiftUI for Apple TV.

**Trademark:** FCast is a registered trademark of FUTO. This is an independent community implementation, not affiliated with FUTO. Per FUTO's trademark policy, the app uses its own unique name ("OvrCast") and original icon, with "FCast-compatible" used only to describe protocol compatibility.

## Key Features
- **FCast Protocol v3**: Full implementation of the open casting standard
- **Bonjour Discovery**: Automatic network discovery so senders find this receiver
- **Real-time Playback Control**: Play, pause, seek, volume from sender apps
- **Multi-Backend Playback**: AVPlayer (HLS/MP4/MOV), TVVLCKit (MKV/WebM/AVI/TS), WebRTC (WHEP screen mirror), Image display
- **Playlist Support**: Opcodes 15 (playUpdate) and 16 (setPlaylistItem)
- **WHEP Screen Mirroring**: Advertises `experimentalCapabilities.av.livestream.whep=true`, implements WebRTC/WHEP client for VP8 streams
- **Demo Mode**: "Play Sample" button on idle screen for App Store reviewers and first-time users

## Project Structure
```
OpenCast/
├── OpenCastApp.swift              # App entry point
├── OpenCast-Bridging-Header.h     # TVVLCKit Obj-C bridge
├── PrivacyInfo.xcprivacy               # App Store privacy manifest
├── Protocol/
│   ├── FCastPackets.swift              # Opcodes, message types, capabilities
│   ├── FCastSession.swift              # TCP session with binary framing
│   └── FCastServer.swift               # TCP server + Bonjour + message dispatch
├── Player/
│   ├── PlayerManager.swift             # Multi-backend player (AVPlayer/VLC/WebRTC/Image)
│   └── WHEPClient.swift                # WebRTC WHEP client for screen mirroring
├── UI/
│   ├── ContentView.swift               # Root view with backend switch
│   ├── IdleView.swift                  # Idle screen with QR code + Play Sample
│   ├── PlayerView.swift                # AVPlayer wrapper
│   ├── VLCPlayerView.swift             # VLC wrapper with Siri Remote controls
│   ├── WebRTCPlayerView.swift          # WebRTC video renderer (RTCMTLVideoView)
│   ├── ImageDisplayView.swift          # AsyncImage for cast images
│   └── AboutView.swift                 # Credits + VLC + trademark attribution
├── Utilities/
│   └── NetworkHelper.swift
└── Assets.xcassets/
```

## Dependencies
- **TVVLCKit** (~> 3.6.0): Universal format playback (MKV, WebM, AVI, etc.) — via CocoaPods
- **WebRTC** (webrtc-sdk/Specs 137.7151.00): WHEP/WebRTC screen mirroring — via SPM
  - NOTE: versions 137.7151.01+ are broken (`.visionOS(.v2)` with swift-tools-version:5.9)
- Build with `.xcworkspace` (not .xcodeproj) due to CocoaPods integration

## Build
```bash
pod install  # first time only
xcodebuild -workspace OpenCast.xcworkspace -scheme OpenCast -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" build
```

## Format Routing (PlayerManager.selectBackend)
| MIME Type | Backend | View |
|-----------|---------|------|
| `application/x-whep` | `.webrtc` | WebRTCPlayerView |
| `image/*` | `.image` | ImageDisplayView |
| `application/x-mpegURL`, `.m3u8` | `.avPlayer` | PlayerView |
| `video/mp4`, `video/quicktime`, `audio/*` | `.avPlayer` | PlayerView |
| Everything else (MKV, WebM, AVI, TS) | `.vlc` | VLCPlayerView |

## Current Status (v1.4, 2026-03-12)
- **Media casting**: WORKING (MP4, MKV, WebM, HLS all confirmed via FCast sender)
- **Image casting**: WORKING
- **Screen mirroring (WHEP)**: Fixed — stored video track race condition resolved, Metal renderer verified
- **Demo mode**: "Play Sample" on idle screen plays Big Buck Bunny MP4
- **Trademark compliance**: Renamed from "FCast Receiver" to "OvrCast" per FUTO trademark policy
- **App Store readiness**: Privacy manifest, original icon, ATS tightened, version bumped

## App Store Submission Notes
- **Bundle ID**: vision.salient.opencast
- **Team**: 44SCLSYCZZ
- **Signing**: Manual — needs new provisioning profile for new bundle ID
- **Privacy**: No data collected, no tracking, no analytics. PrivacyInfo.xcprivacy included.
- **ATS**: `NSAllowsArbitraryLoadsForMedia` + `NSAllowsLocalNetworking` (media receiver plays sender-provided URLs)
- **LGPL**: TVVLCKit is dynamically linked via `use_frameworks!` (LGPL 2.1 compliant)
- **Review notes**: Include instructions to use "Play Sample" button since reviewers won't have an FCast sender

## Test Tools
- `tools/fcast-sender.py` — Python FCast protocol sender for testing
- `tools/fcast-sender.main.kts` — Kotlin version (requires `brew install kotlin`)

## Related Projects
- **Grayjay** (external): Primary sender app that casts to this receiver
- **FCast Desktop** (external): Desktop sender application
- **fightandflowtv** (`~/ios_code/fightandflowtv`): Another tvOS app in the portfolio (different purpose — fitness video)

## Platform
- **Target**: tvOS 17.0+ (Apple TV)
- **Framework**: SwiftUI
- **Media**: AVKit / AVFoundation / TVVLCKit / WebRTC
- **Networking**: Network.framework + Bonjour (NWListener)

## Roadmap
- Subtitle track selection
- Background audio playback
- Event subscription opcodes (17/18/19)
- Migrate TVVLCKit from CocoaPods to SPM (when available)
