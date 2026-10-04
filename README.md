# Interactions

One idea at a time. The app opens into the active prototype — full screen, almost no chrome.

- Display name: **Interactions**
- Bundle ID: `com.jimmy.interactions`
- Language / UI: Swift 6 + SwiftUI
- Minimum iOS: 17.0
- iPhone orientation: **portrait**

Right now the only room is **Candle**: one Metal flame on the field. A quiet slider at the bottom makes that same candle more or less powerful. It does not snap between looks. If Metal is missing, the field stays empty.

Reduce Motion is honored on chrome (the page spring), not on the flame. The flame keeps moving.

## Candle

A photographed candle tongue — bright white-yellow core, thin orange rim, soft glow — centered and shorter than the first upload. Power retunes the core, rim, and body separately; it does not scale one picture, and the ambient wash stays put.

- **Device / Simulator:** drag the power slider
- No microphone. No motion permission. No other rooms.

## Requirements

- A Mac with [Xcode 15](https://developer.apple.com/xcode/) or later (TestFlight CI uses Xcode 26)
- For a physical iPhone: a free Apple ID, or a paid Apple Developer Program team

## Open in Xcode

1. Clone this repository.
2. Open the project (not a workspace — there isn’t one):

   ```bash
   open Interactions.xcodeproj
   ```

   Or in Finder, double-click `Interactions.xcodeproj`.
3. Wait until Xcode finishes indexing (status bar at the top).

## Run on the iOS Simulator

1. In the Xcode toolbar, click the destination control (to the right of the Run ▶ button).
2. Under **iOS Simulator**, pick an iPhone (any iOS 17+ simulator is fine).
3. Press **Run** (▶) or **Command-R**.
4. The candle sits on the field and keeps moving. Drag the slider. Chevrons stay quiet until another room exists.

If no simulators are listed: **Xcode → Settings → Platforms** (or **Components**) and download an iOS simulator runtime.

## Run on a physical iPhone

This is the real thing. Xcode signs the app with your Apple ID / developer team. Automatic signing is already enabled; you only need to choose your team.

### 1. Add your Apple ID in Xcode

1. **Xcode → Settings…** (or **Preferences…**) → **Accounts**.
2. Click **+** → **Apple ID** and sign in with Jimmy’s Apple ID.
3. Close Settings.

### 2. Plug in the iPhone and trust the Mac

1. Connect the iPhone with a cable (or use wireless debugging after the first successful pair).
2. Unlock the phone. If you see **Trust This Computer?**, tap **Trust** and enter the passcode.
3. In Xcode, choose the iPhone from the destination control (it appears under **iOS Device**).

### 3. Select the signing team

1. In the Project Navigator, click the blue **Interactions** project.
2. Select the **Interactions** target.
3. Open **Signing & Capabilities**.
4. Confirm **Automatically manage signing** is checked.
5. Set **Team** to Jimmy’s name (**Personal Team**) or the Apple Developer Program team.

The first time you pick a team, Xcode creates a development certificate and a provisioning profile. Keep the iPhone unlocked while that happens.

If Xcode says the bundle identifier is unavailable, change **Bundle Identifier** to something unique, for example `com.jimmy.interactions.<yourname>`. Display name can stay **Interactions**.

### 4. Enable Developer Mode (iOS 16+)

On the iPhone:

1. **Settings → Privacy & Security → Developer Mode** → turn **On**.
2. Restart the iPhone if prompted, then confirm.

### 5. Build and install

1. Press **Run** (▶) or **Command-R**.
2. If the phone shows **Untrusted Developer**:
   - **Settings → General → VPN & Device Management** (wording varies by iOS version)
   - Tap the Apple ID / developer entry
   - Tap **Trust …** and confirm
3. Run again from Xcode, or tap the **Interactions** icon on the Home Screen.

A free Personal Team install expires after a week; reopen the project in Xcode and Run again to refresh it. A paid Developer Program membership is only required for TestFlight / App Store, not for this local install.

## Ship to TestFlight (no Mac)

You do **not** need a local Mac. GitHub Actions on `macos-15` selects **Xcode 26** (iOS 26 SDK), archives the app, and uploads it to TestFlight with Fastlane + an App Store Connect API key.

Full walkthrough (create the ASC app, API key, secrets, run the workflow, install): **[docs/TESTFLIGHT.md](docs/TESTFLIGHT.md)**.

### One-time setup

1. Register App ID `com.jimmy.interactions` and create the App Store Connect app **Interactions**.
2. Generate an App Store Connect API key (**Admin**) and download the `.p8`.
3. Add these repository secrets (**Settings → Secrets and variables → Actions**):

   | Secret | Value |
   | --- | --- |
   | `APP_STORE_CONNECT_API_KEY_ID` | Key ID |
   | `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (UUID) |
   | `APP_STORE_CONNECT_API_KEY` | Full `.p8` contents (PEM) |
   | `DEVELOPMENT_TEAM` | 10-character Team ID |

   Never commit the `.p8`, certificates, or profiles.

4. The Xcode project stays on **automatic signing** for local Macs. CI **archives unsigned** (GitHub runners have no persistent Development cert), then **exports** with `-allowProvisioningUpdates` plus the API key so Xcode can use Apple’s cloud-managed Distribution certificate and App Store profile. No match repo and no `.p12` secret.

### Ship a build

1. **Actions → TestFlight → Run workflow** (optional: push a `v*` tag).
2. Marketing version is **1.0**. The build number is `github.run_number`.
3. When App Store Connect finishes processing, add the build to an Internal Testing group and install from the **TestFlight** iOS app.
4. On device the app should open on the candle. The flame should already be moving. Drag the slider — same candle, more or less power.

## Switching

Left / right chevrons only — icon, 44pt hit, low contrast, no pills. Next arrives from the right on one spring. No catalog, search, favorites, track chips, or copy. The ordered list lives in `PrototypeCatalog`; arrows stay disabled while there is only one room.

## Project layout

```
Interactions.xcodeproj
Interactions/
  InteractionsApp.swift
  ContentView.swift              Full-screen host + chevrons
  Info.plist
  Experiments/
    PrototypeCatalog.swift       Ordered rooms (candle only)
    Candle/                      Metal candle + power slider
  Assets.xcassets
fastlane/
.github/workflows/testflight.yml
docs/TESTFLIGHT.md
```
