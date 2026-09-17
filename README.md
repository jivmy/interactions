# Interactions

Jimmy’s lab for native iOS interaction experiments. SwiftUI, plus Metal, ARKit, AVFoundation, Core Haptics, and CoreMotion where an experiment needs them.

- Display name: **Interactions**
- Bundle ID: `com.jimmy.interactions`
- Language / UI: Swift + SwiftUI
- Minimum iOS: 17.0
- iPhone orientation: **portrait** (tilt should move the physics, not rotate the chrome)

Open the app and you get a catalog of **18 feel prototypes**. Search, filter by track (A–E), favorite, and jump back in from Continue / Recents. Inside an experiment, the bottom chrome switches neighbors in the same track; the sheet jumps anywhere. Deep link with `interactions://experiment/hanging-chain` (or an `A1`-style code).

The chrome is meant to feel like an Apple design prototype: SF Pro, paper/metal materials, interruptible springs, and Core Haptics that mean something. In-track switches ease a short distance; the thumb bar is a page control. Catalog cards carry a track-color index mark so A–E keep a visual beat. Reduce Motion is honored on chrome, not physics. Metal and fluids pause off-screen. Display links and Metal drop to 60 in Low Power Mode; filings, cloth, and sand publish at 60. Haptic engines shut down when you leave. VoiceOver can adjust the zipper, the dial, and in-track neighbors. Coaching is a single word.

## Experiments

| Code | Title | What to feel | Best hardware | Simulator / fallback |
| --- | --- | --- | --- | --- |
| **A1** | Hanging chain | Metal-ish Verlet rope, gravity + flicks | CoreMotion | Drag a link; no tilt |
| **A2** | Pull-cord light | Limp tug fails; a yank toggles the bulb | Touch velocity | Same — drag the handle |
| **A3** | Compass mercury | Blob sits on true north | Magnetometer + location (true north) | Blob rests in the dish |
| **A4** | Barometric balloon | Lift the phone, balloon climbs | `CMAltimeter` | Drag the balloon |
| **B5** | Safe dial | Click per notch, heavy clunk on the drop | Core Haptics | Visual detents only |
| **B6** | Zipper | Per-tooth ticks while you pull | Core Haptics | Visual teeth only |
| **B7** | Matchbook strike | Fast strike lights; slow scrape is a fun fail | Touch velocity + haptics | Same gesture, no haptics |
| **B8** | Wax seal | Hold to melt, release to stamp | Press duration + haptics | Same gesture, no haptics |
| **C9** | Face-tracked specular | Highlight follows your eyes | TrueDepth / ARKit | Tilt via CoreMotion |
| **C10** | Parallax diorama | Off-axis room as you move your head | TrueDepth / ARKit | Tilt via CoreMotion |
| **C11** | Chladni plate | Sand gathers on standing-wave nodes | Microphone (FFT) | Drag vertically to pick a tone |
| **D12** | Metaball mercury | SDF blobs, smooth-minimum merge | Metal + tilt | Touch still works |
| **D13** | Soap film | Thin-film iridescence, then a pop | Metal + tilt | Tap to pop; colors still animate |
| **D14** | Ink bleed | Touch wicks into paper grain | Touch | Same |
| **D15** | Frost | Dendritic ice from a fingertip | Touch | Same |
| **E16** | Smoke box | Stable fluids; tilt = gravity, finger = force | CoreMotion + touch | Drag to stir |
| **E17** | Cloth panel | Mass-spring sheet | CoreMotion + touch | Drag the cloth |
| **E18** | Iron filings | Finger is a magnetic pole | Touch | Same |

### Hardware notes (real iPhone)

- **CoreMotion (A1, A4, E16, E17, tilt fallbacks):** works on any modern iPhone. Simulator has no gravity hardware.
- **Barometer (A4):** iPhone 6 and later. Relative altitude is zeroed when you open the experiment — lift the phone ~30–40 cm.
- **Compass (A3):** magnetometer. Allow location if you want **true** north; otherwise magnetic north. Indoor metal will pull the blob.
- **Haptics (B5–B8):** Core Haptics on device; silent on Simulator.
- **TrueDepth (C9, C10):** Face ID phones. The front camera usage prompt is for ARKit face tracking, not Face ID unlock. Older devices / Simulator fall back to tilt.
- **Microphone (C11):** grant mic access, then hum or play a tone. Denied / Simulator: drag to change the mode.
- **Metal (D12, D13):** any iPhone; if a GPU is missing the view stays on paper.

First launch may ask for **Motion**, **Microphone**, **Camera**, and (A3) **Location**. Usage strings live in `Interactions/Info.plist`.

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
4. You should see the catalog. Search or filter a track, then open anything. A1 hangs under default gravity — drag a link. Touch experiments (zipper, ink, frost, filings, pull-cord) still play. Tilt / compass / barometer / TrueDepth / haptics will not. The bottom bar switches neighbors; the sheet jumps tracks.

If no simulators are listed: **Xcode → Settings → Platforms** (or **Components**) and download an iOS simulator runtime.

## Run on a physical iPhone

This is the real lab. Xcode signs the app with your Apple ID / developer team. Automatic signing is already enabled; you only need to choose your team.

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
4. On device, open the catalog — A1 should still swing with gravity; the rest of the list should launch without crashing.

## Switching

- **Catalog:** search, A–E track chips, favorites, recents, Continue
- **In an experiment:** prev / next wraps inside the current track (thumb-zone page control), or open the switcher — it starts on the current track
- **Deep link:** `interactions://experiment/<id-or-code>` — e.g. `interactions://experiment/A2`

## Project layout

```
Interactions.xcodeproj
Interactions/
  InteractionsApp.swift
  ContentView.swift              Catalog (search, tracks, favorites, recents)
  Info.plist                     Motion / mic / camera / location + URL scheme
  Experiments/
    ExperimentCatalog.swift      All 18 entries + lookup / neighbors
    Shared/                      Theme, session, chrome, motion, haptics, Metal
    HangingChain/
    PullCord/ CompassMercury/ BarometricBalloon/
    SafeDial/ Zipper/ Matchbook/ WaxSeal/
    FaceSpecular/ ParallaxDiorama/ ChladniPlate/
    MetaballMercury/ SoapFilm/ InkBleed/ Frost/
    SmokeBox/ ClothPanel/ IronFilings/
  Assets.xcassets
fastlane/
.github/workflows/testflight.yml
docs/TESTFLIGHT.md
```

Adding another experiment: append a descriptor to `ExperimentCatalog.all` and put the screen under `Experiments/`.
