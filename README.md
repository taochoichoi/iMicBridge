# iMic Bridge 1.0

A small SwiftUI iOS sample that plays a user-selected audio file and requests Apple's Microphone Injection permission for supported calls.

## Requirements
- Xcode 16.1 or later
- iOS 18.2 or later
- An iPhone/iPad that supports Apple's Add Audio in Calls feature

## Build with GitHub Actions
1. Create a GitHub repository and upload this folder's contents.
2. Open **Actions** and enable workflows if GitHub asks.
3. Run **Build unsigned iOS IPA** using **Run workflow**.
4. Download the `iMicBridge-unsigned-ipa` artifact from the completed workflow.
5. Import that unsigned IPA into SideStore and let SideStore sign/install it with your Apple ID.

The workflow builds an unsigned IPA. It does not contain your Apple signing certificate or provisioning profile; SideStore performs signing on your device.

## Build with Xcode
Open `iMicBridge.xcodeproj`, select the `iMicBridge` scheme and an iOS device destination, then build. Change `PRODUCT_BUNDLE_IDENTIFIER` to a unique identifier if needed.

## Important limitations
- This app plays audio files selected by the user through the Files picker.
- It does **not** capture system audio from YouTube, TikTok, Spotify, games, or other apps. Ordinary iOS apps cannot freely capture another app's output audio.
- Microphone Injection is an iOS feature (iOS 18.2+) and only works when the system reports it available for a compatible active call. The user must enable **Settings > Accessibility > Audio & Visual > Add Audio in Calls** and grant the app permission.
- Compatibility with PUBG Mobile, Litmatch, Discord, other third-party calling apps, and LiveContainer is not guaranteed.
- The source and GitHub workflow are provided for building. They have not been compiled or device-tested in this environment because Xcode/macOS is not available here.
