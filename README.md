# Interactions

Jimmy’s lab for native iOS interaction experiments. SwiftUI, bundle ID `com.jimmy.interactions`.

Shipping today: **A1 Hanging chain** — a Verlet rope pinned at the top of the screen, swung by real device motion.

- Display name: **Interactions**
- Bundle ID: `com.jimmy.interactions`
- Language / UI: Swift + SwiftUI (Canvas + CoreMotion)
- Minimum iOS: 17.0
- iPhone orientation: portrait (so tilting the phone swings the chain instead of rotating the UI)

## A1 Hanging chain — what to feel

Open the app. A metal-ish chain hangs from a pin under the status bar.

On a **real iPhone** (TestFlight or Xcode):

1. Hold the phone upright — the chain hangs down.
2. Tilt left / right — it should swing and then hang toward the floor.
3. Flick or shake the phone — inertia travels down the links.
4. Lay the phone flat on a table — gravity leaves the screen plane and the chain goes slack.
5. Drag a link (or the pendant) with a finger and toss it.

On the **Simulator** there is no CoreMotion hardware. The chain hangs under a default downward gravity; drag a link to play. The caption will say tilt needs a real iPhone.

This is a feel prototype, not game polish. Physics is classic Verlet integration (Jakobsen-style distance constraints) so later rope / tail / cloth experiments can reuse it.

## Requirements

- A Mac with [Xcode 15](https://developer.apple.com/xcode/) or later (Xcode 16 is fine; TestFlight CI uses Xcode 26)
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
4. Simulator launches the app. You should see the hanging chain on a warm paper background. Drag a link — it will not respond to simulated Device → Shake as CoreMotion gravity.

If no simulators are listed: **Xcode → Settings → Platforms** (or **Components**) and download an iOS simulator runtime.

## Run on a physical iPhone

This is the real experiment. Xcode signs the app with your Apple ID / developer team. Automatic signing is already enabled; you only need to choose your team.

The first launch may show a motion-usage prompt (`NSMotionUsageDescription`). Allow it so the chain can read the accelerometer / device motion.

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
4. On device, tilt the phone — the hanging chain should swing with gravity.

## Project layout

```
Interactions.xcodeproj    Open this in Xcode
Interactions/
  InteractionsApp.swift   App entry (@main)
  ContentView.swift       Root: featured experiment (A1)
  Info.plist              NSMotionUsageDescription (merged with generated keys)
  Experiments/
    ExperimentCatalog.swift   Registry — add future experiments here
    HangingChain/
      HangingChainView.swift
      HangingChainSimulation.swift
      VerletRope.swift
      DeviceMotionSource.swift
  Assets.xcassets         App icon + accent color
fastlane/                 TestFlight lanes (API key auth)
.github/workflows/testflight.yml
docs/TESTFLIGHT.md        ASC app + secrets + workflow checklist
```

Adding the next experiment: append to `ExperimentCatalog.all`. Until there is a second one, A1 stays the home screen.
