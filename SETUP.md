# VoiceNoteTaker — Xcode Setup Guide

## Files in this folder

| File | Purpose |
|------|---------|
| `VoiceNoteTakerApp.swift` | `@main` entry point + `AppDelegate` |
| `TranscriptionEngine.swift` | `SFSpeechRecognizer` + `AVAudioEngine` logic |
| `StatusBarController.swift` | `NSStatusItem`, menu, hotkey, popover |
| `PopoverView.swift` | SwiftUI history panel |
| `VoiceNoteTaker.entitlements` | Microphone entitlement |

---

## Step 1 — Create the Xcode project

1. Open **Xcode 15+**
2. **File → New → Project…**
3. Choose **macOS → App** → click Next
4. Fill in:
   - **Product Name:** `VoiceNoteTaker`
   - **Team:** your Apple ID (free team is fine for local dev)
   - **Bundle Identifier:** e.g. `com.yourname.VoiceNoteTaker`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - Uncheck "Include Tests"
5. Save into this folder (choose the parent `swift/` folder as location so Xcode creates `VoiceNoteTaker/VoiceNoteTaker.xcodeproj` here).

---

## Step 2 — Replace generated files

Xcode creates its own `VoiceNoteTakerApp.swift` and `ContentView.swift`. Replace them:

1. In the Xcode project navigator, **delete** `ContentView.swift` (Move to Trash).
2. **Delete** the auto-generated `VoiceNoteTakerApp.swift` (Move to Trash).
3. **Drag** all `.swift` files from this folder into the Xcode project navigator under the `VoiceNoteTaker` group:
   - `VoiceNoteTakerApp.swift`
   - `TranscriptionEngine.swift`
   - `StatusBarController.swift`
   - `PopoverView.swift`
4. In the dialog that appears: check **"Copy items if needed"** is OFF (files are already in the right place), and make sure **"Add to target: VoiceNoteTaker"** is checked.

---

## Step 3 — Add the entitlements file

1. In the Xcode project navigator, drag `VoiceNoteTaker.entitlements` into the `VoiceNoteTaker` group.
2. Click the **project** in the navigator (blue icon) → select the **VoiceNoteTaker** target → **Signing & Capabilities** tab.
3. In the "Signing" section, click the folder icon next to "Entitlements File" and select `VoiceNoteTaker.entitlements`.
   - Alternatively Xcode may auto-detect it by name match.

> **Note:** App Sandbox is set to `false` in the entitlements — this is required for global hotkey monitoring (`NSEvent.addGlobalMonitorForEvents`). If you later distribute via the Mac App Store, sandbox must be `true` and you must remove the global hotkey monitor.

---

## Step 4 — Configure Info.plist

Select `Info.plist` in the navigator (or use the target's **Info** tab) and add these keys:

| Key | Type | Value |
|-----|------|-------|
| `NSMicrophoneUsageDescription` | String | `VoiceNoteTaker needs microphone access to record your voice.` |
| `NSSpeechRecognitionUsageDescription` | String | `VoiceNoteTaker uses speech recognition to transcribe your recordings.` |
| `LSUIElement` | Boolean | `YES` |

`LSUIElement = YES` hides the Dock icon and removes the app from the Cmd+Tab switcher.

---

## Step 5 — Deployment target

1. Click the project (blue icon) → select the **VoiceNoteTaker** target → **General** tab.
2. Set **Minimum Deployments** → **macOS 13.0**.

---

## Step 6 — Disable Hardened Runtime for local dev (optional)

For local testing without a paid developer account, skip Hardened Runtime:

1. Target → **Signing & Capabilities** tab.
2. If "Hardened Runtime" capability is listed, remove it (click the `–` button) **for Debug only**.

This avoids notarization requirements during development. For distribution you'll need it back plus the `com.apple.security.device.audio-input` entitlement.

---

## Step 7 — Build and Run

1. Press **⌘R** or **Product → Run**.
2. On first launch macOS will ask for:
   - Speech Recognition permission
   - Microphone permission
   
   Accept both. If denied, the icon turns yellow with an error — open System Settings → Privacy & Security to re-enable.

3. A `🎙` icon appears in the menu bar.

---

## Using the app

| Action | Result |
|--------|--------|
| **Left-click** menu bar icon | Start / stop recording |
| **Right-click** menu bar icon | Open menu |
| **⌘⇧R** (global hotkey) | Start / stop recording from any app |
| Stop recording | Final text copied to clipboard automatically |
| Right-click → Show History | Open popover with past transcriptions |
| Right-click → Language | Switch recognition locale |
| Right-click → Clear History | Wipe all entries |

---

## Icon states

| Icon | Color | Meaning |
|------|-------|---------|
| `mic` | Default | Idle |
| `mic.fill` | Red | Recording |
| `ellipsis.bubble.fill` | Orange | Processing (transcribing) |
| `exclamationmark.triangle.fill` | Yellow | Error (hover for details) |

---

## Troubleshooting

**"Speech recognizer unavailable"** — The selected locale may not be downloaded. Go to System Settings → General → Language & Region → check speech languages.

**No audio / silent recording** — Another app may own the mic exclusively. Quit audio apps and try again.

**Global hotkey not working** — macOS may require Accessibility permission. The app requests mic/speech but not Accessibility. If needed, add it manually in System Settings → Privacy → Accessibility.

**"main attribute cannot be used in module with top-level code"** — SourceKit false positive from editing files outside Xcode. Build inside Xcode — it will compile cleanly.
