# ⚡️ CastNow - Native P2P Screen Sharing

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com)
[![WebRTC](https://img.shields.io/badge/WebRTC-333333?style=for-the-badge&logo=webrtc&logoColor=white)](https://webrtc.org)

**CastNow** is a powerful, high-performance peer-to-peer (P2P) screen sharing application built with Flutter. It allows users to broadcast their mobile screen or camera directly to other devices without any intermediate servers, ensuring maximum privacy and minimal latency.

---

## ✨ Key Features

- 🚀 **P2P Direct Streaming**: Utilizes WebRTC for direct device-to-device communication.
- 📱 **Screen & Camera Support**: Toggle between sharing your entire screen or your front/back camera.
- 🔒 **Secure Connection**: Data is encrypted and stays between peers – no cloud storage or server-side processing.
- 🤖 **Android 14 Ready**: Fully optimized for Android 14 (API 34) with foreground services and media projection support.
- 📺 **Reliable Termination**: Intelligent session handling that detects when sharing is stopped via the app, notification, or system UI.
- 🎨 **Modern Aesthetics**: Sleek dark-mode UI with a premium glassmorphism design.
- ⏳ **Session Management**: Built-in logic for free exploration and pro-tier features.

---

## 🛠 Tech Stack

- **Frontend**: Flutter (Dart)
- **Networking/Broadcasting**: 
  - `flutter_webrtc`: Core streaming engine.
  - `peerdart`: Peer-to-peer signaling simplified.
- **Native Android (Kotlin)**:
  - `MediaProjectionManager`: For high-quality screen capture.
  - `Foreground Service`: To maintain streaming in the background.
  - `DisplayListener`: To monitor capture state changes.
- **State Management**: `StatefulWidget` (Optimized for simplicity and performance).

---

## 📱 Android 14 Specifics

On Android 14+, screen capture requires strict foreground service management. CastNow implements:
- **`MediaProjectionService`**: A dedicated service with `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION`.
- **System Callback Integration**: Listens for the `Display.STATE_OFF` signal and display removal to ensure the UI stays in sync with the system's screen-sharing status.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (Latest stable version recommended)
- Android Studio / VS Code
- An Android device or emulator with API 30+

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/MinghuaLiu1977/castnow.git
   cd castnow/app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   ```bash
   flutter run
   ```

---

## 📂 Project Structure

```text
app/
├── android/          # Native Android implementation (Kotlin/Service)
├── ios/              # iOS configuration
├── lib/
│   ├── main.dart     # Main application logic & UI
│   └── ...           # Other Dart helpers
└── assets/           # UI Assets and Styles
```

---

## 🤝 Contribution

Contributions are welcome! Feel free to open issues or submit pull requests to improve CastNow.

## 📄 License & Terms

CastNow is provided by **Eastlake Studio**.
- **Privacy**: We do not collect any stream data.
- **Usage**: By using this app, you agree to be responsible for the content you share.

---

<p align="center">Made with ❤️ by <b>Eastlake Studio</b></p>
