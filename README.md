# VoiceNoteTaker

A lightweight macOS menu bar app that records your voice and transcribes it using Apple's built-in Speech framework — no API keys, no subscriptions, no Dock icon.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![No dependencies](https://img.shields.io/badge/dependencies-none-green)

---

## Features

- **Menu bar only** — no Dock icon, no main window
- **Click or hotkey** to start/stop recording (global `⌘⇧R` works from any app)
- **Live transcription** visible in the popover while recording
- **Auto-copy** — final transcription is copied to clipboard on stop
- **History panel** — last N transcriptions with timestamps, per-entry copy button
- **Language selector** — switch recognition locale from the right-click menu
- **On-device first** — uses downloaded local model when available; falls back to Apple's server
- **Permission guidance** — clear error messages when mic or speech recognition is denied

## Requirements

| | |
|---|---|
| macOS | 13 Ventura or later |
| Xcode | 15 or later |
| Dependencies | None (pure Swift, Apple frameworks only) |

## Quick Start

```bash
# Open directly in Xcode
open VoiceNoteTaker.xcodeproj
```

1. Set your **Team** in *Signing & Capabilities* (any Apple ID works for local dev)
2. Press **⌘R**
3. Accept the microphone and speech recognition permission prompts
4. Click the `🎙` menu bar icon or press **⌘⇧R** to start recording

See [`SETUP.md`](SETUP.md) for full Xcode wiring details.

## Usage

| Action | Result |
|---|---|
| Left-click menu bar icon | Toggle recording |
| Right-click menu bar icon | Open menu |
| `⌘⇧R` (global) | Toggle recording from any app |
| Stop recording | Final text copied to clipboard |
| Right-click → Show History | Open transcription history panel |
| Right-click → Language | Switch recognition locale |
| Right-click → Clear History | Wipe all entries |

### Icon states

| Icon | Color | Meaning |
|---|---|---|
| `mic` | Default | Idle |
| `mic.fill` | Red | Recording |
| `ellipsis.bubble.fill` | Orange | Processing |
| `exclamationmark.triangle.fill` | Yellow | Error |

## Architecture

```
VoiceNoteTaker/
├── VoiceNoteTakerApp.swift       @main entry + AppDelegate (hides Dock icon)
├── TranscriptionEngine.swift     @MainActor ObservableObject — AVAudioEngine + SFSpeechRecognizer
├── StatusBarController.swift     @MainActor — NSStatusItem, menu, global hotkey
├── PopoverView.swift             SwiftUI history panel
├── Assets.xcassets               App icon + accent color
├── Info.plist                    LSUIElement, mic/speech usage strings
└── VoiceNoteTaker.entitlements   Microphone entitlement
```

**Key design decisions:**
- `TranscriptionEngine` and `StatusBarController` are both `@MainActor` — all state mutations on the main thread, no manual `DispatchQueue` juggling
- Recognition callbacks bounce back via `Task { @MainActor in }` 
- 4-second fallback timer in `stopRecording()` prevents hanging in `.transcribing` state if `isFinal` never fires
- `didFinish` flag prevents double-calling `finishTranscription()` when timer and callback race
- App Sandbox is disabled — required for `NSEvent.addGlobalMonitorForEvents` (global hotkeys)

## Speech Recognition Notes

The app uses `SFSpeechRecognizer` with locale auto-detected from your system language.

**On-device vs. server:** The app prefers on-device recognition (`recognizer.supportsOnDeviceRecognition`) when a local model is downloaded, avoiding any network dependency. Otherwise it falls back to Apple's speech servers.

**To enable on-device recognition:**
> System Settings → Siri & Dictation → Languages → download your language

**Error `kAFAssistantErrorDomain 203`:** Apple's speech backend unreachable. Check internet connection or download the on-device model for your locale.

## Permissions

| Permission | Why |
|---|---|
| Microphone | Capture audio for transcription |
| Speech Recognition | Convert audio to text via `SFSpeechRecognizer` |

Both are requested on first launch. If denied, re-enable in **System Settings → Privacy & Security**.

## Distribution Notes

App Sandbox is off (required for global hotkeys). For **Mac App Store** distribution:
- Enable sandbox (`com.apple.security.app-sandbox = true`)
- Add `com.apple.security.device.audio-input = true`
- Replace `NSEvent.addGlobalMonitorForEvents` with a sandboxed hotkey approach (e.g. `Carbon` `RegisterEventHotKey` via a helper, or remove global hotkey)
