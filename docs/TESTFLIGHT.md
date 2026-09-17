# TestFlight (no Mac)

Ship **Interactions** (`com.jimmy.interactions`) to TestFlight from GitHub Actions. You do not need a local Mac. The workflow runs on GitHub-hosted `macos-14` runners (not a Cursor Mac pool).

Version **1.0**; each CI run uses `github.run_number` as the build number (`CFBundleVersion`).

## Checklist

Do these once, then you can re-run the workflow for every new build.

1. [ ] Apple Developer Program membership is active (Jimmy).
2. [ ] App Store Connect paid-apps / free-apps agreements are accepted.
3. [ ] Register the App ID `com.jimmy.interactions`.
4. [ ] Create the App Store Connect app **Interactions**.
5. [ ] Create an App Store Connect API key (Admin) and download the `.p8`.
6. [ ] Copy the 10-character Development Team ID.
7. [ ] Add the four GitHub Actions secrets listed below.
8. [ ] Run **Actions → TestFlight → Run workflow**.
9. [ ] Install from the TestFlight app after processing finishes.

Do **not** commit the `.p8`, `.p12`, provisioning profiles, or any secret values.

## 1. Register the App ID

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
2. **Identifiers → +**.
3. Choose **App IDs → App**.
4. Description: `Interactions`.
5. Bundle ID: **Explicit** `com.jimmy.interactions`.
6. Capabilities: leave the defaults (blank SwiftUI app).
7. **Continue → Register**.

## 2. Create the App Store Connect app

1. Open [App Store Connect → Apps](https://appstoreconnect.apple.com/apps).
2. **+ → New App**.
3. Platform: **iOS**.
4. Name: `Interactions`.
5. Primary language: English (or your preference).
6. Bundle ID: `com.jimmy.interactions`.
7. SKU: `interactions` (internal; not shown to users).
8. User Access: Full Access (or limit as you prefer).
9. Create the app.

First-time accounts may also need to complete the **Tax**, **Banking**, and **Paid Applications** / **Free Applications** agreements under **Business**. Uploads fail until those are accepted.

## 3. Create an App Store Connect API key

Xcode on the runner authenticates with this key (no Apple ID password, no SMS 2FA).

1. [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. **Request Access** if prompted, then **Generate API Key**.
3. Name: `GitHub Actions TestFlight`.
4. Access: **Admin**.
   - Admin can create Apple’s cloud-managed distribution certificate and App Store profiles on first upload.
   - **App Manager** can upload builds after signing assets already exist; use **Admin** for the first CI run.
5. Download the `.p8` file. Apple shows it **once** — store it in a password manager, not git.
6. Note:
   - **Key ID** (10 characters, e.g. `AB12CD34EF`)
   - **Issuer ID** (UUID at the top of the API keys page)

The file looks like:

```
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

Revoke the key in App Store Connect if it ever leaks. GitHub secrets are not automatically rotated.

## 4. Find the Development Team ID

1. [developer.apple.com/account](https://developer.apple.com/account) → **Membership details**.
2. Copy **Team ID** (10 characters, e.g. `A1B2C3D4E5`).

This is the Apple Developer Program team, not a free Personal Team.

## 5. GitHub secrets

Repo: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | What to paste |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from step 3 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID UUID from step 3 |
| `APP_STORE_CONNECT_API_KEY` | Full `.p8` file contents, including `BEGIN` / `END` lines |
| `DEVELOPMENT_TEAM` | 10-character Team ID from step 4 |

Paste the PEM into `APP_STORE_CONNECT_API_KEY` as multiline text. Do not base64-encode it. Do not wrap it in quotes.

Confirm the names match exactly. The workflow fails fast with a missing-secret error if any of the four is empty (this is expected until you add them).

## 6. Certificates and profiles

The Xcode project stays on **automatic signing** for local Macs. CI does **not** store a `.p12` or a match repo.

GitHub-hosted `macos-14` runners are ephemeral (empty keychain every job). Automatic **archive** signing always wants an **Apple Development** certificate for “this machine” plus an **iOS App Development** profile. The first CI archive can create that Development cert; the next runner does not have the private key and fails with:

> Revoke certificate: Your account already has an Apple Development signing certificate for this machine, but its private key is not installed in your keychain.

So the TestFlight lane splits archive and export:

1. Writes the API key to a temp `.p8` (never committed).
2. **Archives unsigned** (`CODE_SIGNING_ALLOWED=NO`). No Development cert, no development profile, no registered device required.
3. **Exports** the archive with `signingStyle: automatic`, `method: app-store`, `-allowProvisioningUpdates`, and Apple’s `-authenticationKeyPath` / `-authenticationKeyID` / `-authenticationKeyIssuerID`.
4. Xcode creates or refreshes the **cloud-managed Apple Distribution certificate** and the **App Store** provisioning profile for `com.jimmy.interactions`.
5. Fastlane uploads the IPA with `upload_to_testflight`.

Why not generate a new Distribution certificate every run (`fastlane cert` / a local CSR)? GitHub runners are ephemeral. A new private key each job would burn through Apple’s **three Distribution certificates** limit. Cloud-managed signing keeps the private key at Apple and downloads it for that export.

Do **not** set `CODE_SIGN_IDENTITY` to `Apple Distribution` while `CODE_SIGN_STYLE` is Automatic. That is a different failure (`conflicting provisioning settings`). Identity stays unset in the project; distribution signing happens only at export.

### Optional one-time portal cleanup

Not required for the next workflow run, but useful if earlier CI jobs created leftover certs:

1. Open [Certificates, Identifiers & Profiles → Certificates](https://developer.apple.com/account/resources/certificates/list).
2. You may revoke **Apple Development** certificates that were created by GitHub Actions (runner hostnames / “Created via API”). Keep any Development cert you use on a real Mac.
3. Do **not** revoke the **cloud-managed Apple Distribution** certificate Xcode created for App Store / TestFlight.
4. If export fails because the team already has three **Apple Distribution** certificates, revoke unused *CSR / local Mac* Distribution certs and keep the cloud-managed one, then re-run.

Notes:

- The first successful export may take longer while Apple issues the Distribution certificate and App Store profile.
- You should **not** need to download profiles or export a `.p12` from a Mac.
- Manual fallback (only if automatic export is blocked on the team): create an Apple Distribution certificate on a trusted machine, export a `.p12`, and add extra secrets. That path is not wired up in this workflow on purpose.

## 7. Run the workflow

1. Push this branch / merge to the branch you want to ship (usually `main`).
2. GitHub → **Actions → TestFlight**.
3. **Run workflow**.
4. Optional: fill **What to Test**.
5. Wait for **Archive and upload to TestFlight**.

Optional tag trigger: pushing a tag matching `v*` (for example `v1.0.0`) also runs the same job. The marketing version stays **1.0** until you change `MARKETING_VERSION` in `.github/workflows/testflight.yml`; tags do not change the number by themselves.

Build number is `github.run_number` (monotonic per repository). If an upload is rejected as a duplicate version, run the workflow again so you get a new number.

## 8. Install via TestFlight

Internal testers (no Beta App Review):

1. App Store Connect → **Apps → Interactions → TestFlight**.
2. Wait until the build leaves **Processing** (often 5–15 minutes after a green workflow).
3. **Internal Testing → +** to create a group if needed.
4. Add testers (App Store Connect users on the team).
5. Add the new build to the group.

On the iPhone:

1. Install **TestFlight** from the App Store.
2. Accept the tester invite email / redeem code, or open TestFlight while signed into the same Apple ID.
3. Install **Interactions**.
4. You should see the blank white screen (same as Simulator).

External testers need Beta App Review the first time, plus compliance details. This blank app sets `ITSAppUsesNonExemptEncryption = NO` so export-compliance questions do not block processing.

## What CI changes vs what stays in git

| Item | Value |
| --- | --- |
| Display name | Interactions |
| Bundle ID | `com.jimmy.interactions` |
| Marketing version | `1.0` (in the project; CI also passes `MARKETING_VERSION=1.0`) |
| Build number | `github.run_number` (CI only; not committed) |
| Signing | Archive unsigned; export automatic App Store (cloud-managed Distribution) |
| Team | `DEVELOPMENT_TEAM` secret (CI only; not committed) |

The SwiftUI UI is unchanged. CI injects the team id and build number through `xcodebuild` / Fastlane and does not commit those edits.

## Local Fastlane (optional)

There is still no requirement for a Mac. If you later use a Mac:

```bash
bundle install
bundle exec fastlane ios doctor   # no upload
bundle exec fastlane ios beta     # archive + TestFlight (needs the same env vars)
```

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Workflow fails “Missing GitHub secret” | The four names in [§5](#5-github-secrets) |
| `option '-authenticationKeyPath' may only be provided once` (exit 64) | gym forwards both `xcargs` and `export_xcargs` to `-exportArchive`. Pass ASC API key flags (`-authenticationKeyPath` / `-authenticationKeyID` / `-authenticationKeyIssuerID`) and `-allowProvisioningUpdates` in the **export** `xcargs` only — not also in `export_xcargs`, and not on the unsigned archive step |
| `Revoke certificate` / `No profiles for 'com.jimmy.interactions'` (iOS **App Development**) | Archive tried to use a machine Apple Development cert. CI must archive unsigned (`skip_codesigning`) and sign only at App Store export. Optional: revoke leftover CI **Apple Development** certs ([§6](#6-certificates-and-profiles)) |
| `conflicting provisioning settings` / `Apple Distribution has been manually specified` | Do not set `CODE_SIGN_IDENTITY` to Apple Distribution while automatic signing is on. Leave identity unset in the project; gym exports with `signingStyle: automatic` |
| `No signing certificate` / `No profiles` on **export** (App Store) | API key Access is **Admin**; App ID exists; Team ID is the ADP team; unused extra Apple Distribution certs may need revoking ([§6](#6-certificates-and-profiles)) |
| `Authentication credentials are missing or invalid` | Issuer ID, Key ID, and `.p8` belong to the same key; PEM includes BEGIN/END |
| Duplicate `CFBundleVersion` | Re-run the workflow (new `run_number`) |
| Build stuck on export compliance | Confirm `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` in the target |
| `App does not exist` / could not find bundle | [§2](#2-create-the-app-store-connect-app) |
| Agreements missing | App Store Connect → Business → Agreements |
| Icon validation | A 1024×1024 `AppIcon.png` is in the asset catalog (required to archive) |

Do not run a real upload from this documentation environment without secrets. After secrets are in GitHub, the **TestFlight** workflow is the upload path.
