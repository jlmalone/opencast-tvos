  Response to Guideline 2.1 - Information Needed

  1. How does your tvOS app connect with the FCast sender?

  FCast Receiver uses Apple's standard Bonjour/mDNS protocol to advertise itself on the local network as a _fcast._tcp service on TCP port 46899. When a
  compatible sender app (such as Grayjay, or FCast Desktop) is on the same Wi-Fi network, it discovers the receiver automatically through Bonjour service
  discovery — the same mechanism used by AirPlay and other local network services.

  Once a sender selects the receiver, a standard TCP connection is established on port 46899. The two devices perform a version handshake (FCast Protocol v3),
  exchange device metadata (display name, app name, app version), and the sender can then issue playback commands (play, pause, seek, volume, etc.) as
  length-prefixed binary frames containing JSON payloads. The receiver responds with playback state updates every 500ms so the sender's UI stays synchronized.

  FCast is an open-source, patent-free casting protocol created by FUTO. The protocol specification is publicly available at https://fcast.org and reference
  implementations are at https://github.com/futo-org/fcast.

  2. Detailed steps to connect to the Apple TV device:

  1. Launch FCast Receiver on Apple TV. The idle screen displays the device name, local IP address, and a QR code.
  2. Ensure the sender device (iPhone, Mac, PC, etc.) is on the same Wi-Fi network as the Apple TV.
  3. Open a compatible sender app (e.g., Grayjay on Android/iOS, or FCast Desktop on Mac/PC).
  4. In the sender app, tap the cast icon. The app scans the local network via Bonjour and the Apple TV appears in the list of available receivers.
  5. Select the Apple TV from the list. The TCP connection and handshake happen automatically.
  6. Browse media in the sender app and select content to cast. The sender transmits the media URL to the receiver, which begins playback on the TV.
  7. The sender app provides real-time playback controls (play, pause, seek, volume, speed) throughout the session.

  Alternative connection method: If Bonjour discovery is unavailable, the user can scan the QR code displayed on the Apple TV's idle screen from within the
  sender app, which encodes the receiver's IP and port for direct connection.
