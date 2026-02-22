# CLAUDE.md - FCast AppleTV Receiver

## Overview
Native tvOS application implementing the FCast protocol v3 for receiving cast video/audio streams from Grayjay and FCast desktop senders. Built with SwiftUI for Apple TV.

## Key Features
- **FCast Protocol v3**: Full implementation of the open casting standard
- **Bonjour Discovery**: Automatic network discovery so senders find this receiver
- **Real-time Playback Control**: Play, pause, seek, volume from sender apps
- **Video/Audio Streaming**: Receives and plays media streams cast from desktop/mobile

## Project Structure
```
FCastReceiver/
├── FCastReceiverApp.swift    # App entry point
├── Protocol/                 # FCast protocol v3 implementation
├── Player/                   # AVPlayer-based media playback
├── UI/                       # SwiftUI views for tvOS
├── Utilities/                # Helper code
├── Assets.xcassets           # App assets
└── Info.plist                # tvOS configuration
```

## Build
```bash
xcodebuild -project FCastReceiver.xcodeproj -scheme FCastReceiver -destination "platform=tvOS Simulator,name=Apple TV" build
```

## Related Projects
- **Grayjay** (external): Primary sender app that casts to this receiver
- **FCast Desktop** (external): Desktop sender application
- **fightandflowtv** (`~/ios_code/fightandflowtv`): Another tvOS app in the portfolio (different purpose — fitness video)

## Platform
- **Target**: tvOS (Apple TV)
- **Framework**: SwiftUI
- **Media**: AVKit / AVFoundation
- **Networking**: Network.framework + Bonjour (NWListener)
