# Conduit

<div align="center">

![Latest Release](https://img.shields.io/github/v/release/cogwheel0/conduit?display_name=tag&color=8A2BE2)
![GitHub all downloads](https://img.shields.io/github/downloads/cogwheel0/conduit/total?style=flat-square&label=Downloads&logo=github&color=0A84FF)


<a href="https://play.google.com/store/apps/details?id=app.cogwheel.conduit">
<img src="store-badges/google.webp" alt="Get it on Google Play" style="height:56px;"/>
</a>
<a href="https://apps.apple.com/us/app/conduit-open-webui-client/id6749840287">
<img src="store-badges/apple.webp" alt="Download on the App Store" style="height:56px;"/>
</a>

</div>

<br>

<div align="center">
<img src="docs/conduit-demo.gif" alt="Conduit Demo" style="height:600px;"/>
</div>

<br>

Conduit is an open-source, cross-platform mobile application for Open-WebUI, providing a native mobile experience for interacting with your self-hosted AI infrastructure.

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Requirements](#requirements)
- [Quickstart](#quickstart)
- [Installation](#installation)
- [Building for Release](#building-for-release)
- [Configuration](#configuration)
- [Localization (i18n)](#localization-i18n)
- [Compatibility](#compatibility)
- [Docs](#docs)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [Security & Privacy](#security--privacy)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Quickstart

```bash
git clone https://github.com/cogwheel0/conduit && cd conduit
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run -d ios   # or: -d android
```

## Features

### Core Features
- **Real-time Chat**: Stream responses from AI models in real-time
- **Model Selection**: Choose from available models on your server
- **Conversation Management**: Create, search, and manage chat histories
- **Markdown Rendering**: Full markdown support with syntax highlighting
- **Theme Support**: Light, Dark, and System themes

### Advanced Features
- **Voice Input**: Use speech-to-text for hands-free interaction
- **File Uploads**: Support for images and documents (RAG)
- **Multi-modal Support**: Work with vision models
- **Secure Storage**: Credentials stored securely using platform keychains
- **Folder Management**: Organize conversations into folders; create, rename, move, and delete
 - **Tools (Function Calling)**: Invoke server-side tools exposed by Open‑WebUI, with result rendering

### Authentication
Conduit supports multiple authentication flows when connecting to your Open‑WebUI:
- **Username + Password**: Sign in directly against servers that expose a login endpoint. Credentials are stored securely using platform keychains.
- **API Key**: Paste a server‑issued API token for stateless auth.
- **Custom Headers**: Add headers during login (e.g., `X-API-Key`, `Authorization`, `X-Org`, or self‑hosted SSO headers) that Conduit will include on all HTTP/WebSocket requests (see [Endpoint Allowlist](#endpoint-allowlist-custom-auth) for reverse proxy whitelisting).

## Screenshots

| | | | |
| --- | --- | --- | --- |
| <img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/2_en-US.png" alt="Screenshot 2" width="200" /> | <img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/3_en-US.png" alt="Screenshot 3" width="200" /> | <img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/4_en-US.png" alt="Screenshot 4" width="200" /> | <img src="android/fastlane/metadata/android/en-US/images/phoneScreenshots/5_en-US.png" alt="Screenshot 5" width="200" /> |

## Requirements

- Flutter SDK 3.0.0 or higher
- Android 6.0 (API 23) or higher
- iOS 12.0 or higher
- A running Open-WebUI instance

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/conduit.git
cd conduit
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. Run the app:
```bash
# For iOS
flutter run -d ios

# For Android
flutter run -d android
```

## Building for Release

### Android
```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Building with Pre-configured Server URL (Enterprise/Custom Deployments)

For enterprise deployments or custom builds where you want to pre-configure the server URL, you can use the `--dart-define` flag during build:

```bash
# Android APK with pre-configured server
flutter build apk --dart-define=DEFAULT_SERVER_URL=https://your-company-server.com

# iOS with pre-configured server
flutter build ios --dart-define=DEFAULT_SERVER_URL=https://your-company-server.com

# Multiple builds for different organizations
flutter build apk --dart-define=DEFAULT_SERVER_URL=https://company-a.com -o company-a.apk
flutter build apk --dart-define=DEFAULT_SERVER_URL=https://company-b.com -o company-b.apk
```

**How it works:**
- When a pre-configured URL is set, the app performs a **health check** on first launch
- If the server is **valid and reachable**, a server configuration is automatically created
- Users will skip the server URL input screen and go directly to the login screen
- Users can still change the server URL later via the back button on the authentication page
- If no `DEFAULT_SERVER_URL` is provided, the app behaves normally (users must enter server URL manually)

**Important notes:**
- ⚠️ **The server URL must be valid and reachable** - The app will perform a health check (5 second timeout) before accepting the pre-configured URL
- ⚠️ **If the health check fails** (invalid URL, server down, timeout, or not an Open-WebUI server), the app will show the normal server connection page after ~5 seconds
- ✅ This prevents infinite loading issues from incorrect or unreachable server URLs
- ✅ Fast startup: Invalid servers are detected and skipped within 5 seconds
- ✅ Users can always fix configuration issues by entering a valid URL manually

**Example use cases:**
- Enterprise deployments with a fixed internal server
- White-label builds for specific organizations
- Simplified onboarding for non-technical users

## Configuration

### Android
The app requires the following permissions:
- Internet access
- Microphone (for voice input)
- Camera (for taking photos)
- Storage (for file selection)

### iOS
The app will request permissions for:
- Microphone access (voice input)
- Speech recognition
- Camera access
- Photo library access

## Architecture

The app follows a clean architecture pattern with:
- **Riverpod** for state management
- **Dio** for HTTP networking
- **WebSocket** for real-time streaming
- **Flutter Secure Storage** for credential management

### Project Structure
```
lib/
├── core/
│   ├── models/         # Data models
│   ├── services/       # API and storage services
│   ├── providers/      # Global state providers
│   └── utils/          # Utility functions
├── features/
│   ├── auth/           # Authentication feature
│   ├── chat/           # Chat interface feature
│   ├── server/         # Server connection feature
│   └── settings/       # Settings feature
└── shared/
    ├── theme/          # App theming
    ├── widgets/        # Shared widgets
    └── utils/          # Shared utilities
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

Developer workflow:

```bash
flutter analyze
flutter pub run build_runner build --delete-conflicting-outputs
# flutter test  # add when tests are available
```

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Troubleshooting

- iOS: ensure recent Xcode, run `cd ios && pod install`, set signing team in Xcode if building on device.
- Android: minSdk 23+, ensure correct Java and Gradle; if builds fail, try `flutter clean`.
- Codegen conflicts: `flutter pub run build_runner build --delete-conflicting-outputs`.

## Security & Privacy

- Credentials are stored using platform secure storage (Keychain/Keystore).
- No analytics or telemetry are collected.
- Network calls are only made to your configured Open‑WebUI server.

### Endpoint Allowlist (Custom Auth)

If you protect Open‑WebUI with SSO or a reverse proxy (Authlia, Authentik,
etc.), whitelist these path prefixes so Conduit can complete login, sync, and
streaming flows. Paths are relative to your server base URL.

- `/health`
- `/api/*`

WebSocket connections use the Socket.IO handshake on `/ws/socket.io`. Ensure the
same headers (or allowlist rules) apply there as well.

## License

This project is licensed under the GPL3 License - see the LICENSE file for details.

## Acknowledgments

- Open-WebUI team for creating an amazing self-hosted AI interface
- Flutter team for the excellent mobile framework
- All contributors and users of Conduit

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/cogwheel0/conduit/issues) page.
