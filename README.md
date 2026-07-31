# playback-popup

A tiny, native-feeling macOS menu-bar utility with a single purpose: whenever the
**currently playing media item changes** (song → next song, video → next video, playlist
advance), it briefly shows a translucent "Now Playing" popup near the top-right of the
screen for ~2.7 s, then fades away. Album artwork, title, artist, and one Play/Pause
button — nothing else.

It runs as an accessory app (menu-bar only, no Dock icon), stays idle at rest, and is
built to fail gracefully if media monitoring ever stops working.

## How it reads "Now Playing" (important)

macOS has **no public API** for reading system-wide Now Playing info, and Apple locked the
private `MediaRemote.framework` behind an entitlement in **macOS 15.4+**. The one technique
that still works on macOS 26 (Tahoe) is the BSD-licensed
[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter): it invokes
`/usr/bin/perl` (an Apple binary that *does* carry the entitlement) to load a helper
framework that streams Now Playing changes as newline-delimited JSON.

Consequences: this app is **not** Mac App Store distributable, it bundles/uses a small Perl
bridge, and it must run un-sandboxed so it can spawn `perl`.

## Architecture

| File | Responsibility |
|------|----------------|
| `playback_popupApp.swift` | App entry: `MenuBarExtra` + delegate adaptor; status icon/line reflects health |
| `AppDelegate.swift` | Wires monitor → popup → control; accessory activation policy |
| `AdapterLocation.swift` | **The Phase-1/Phase-2 seam** — resolves the perl script + framework paths |
| `AdapterProcess.swift` | Non-isolated wrapper around the long-lived `perl … stream` subprocess |
| `NowPlayingMonitor.swift` | Merges the JSON diff stream; decides when the *item* changed; health + restart |
| `NowPlayingItem.swift` | Media snapshot + stable `identity` used for change detection |
| `MediaRemoteControl.swift` | Sends the play/pause toggle (`perl … send 2`) |
| `PopupController.swift` | Show / update-in-place / auto-dismiss; positioning + animations |
| `PopupPanel.swift` | Borderless, non-activating floating panel |
| `NowPlayingView.swift` | The SwiftUI content (artwork, title, artist, Play/Pause) |
| `VisualEffectView.swift` | Native vibrancy + rounded corners |
| `Appearance.swift` | **Every UI constant** — sizes, radii, spacing, durations, margins |
| `Log.swift` | Unified-logging categories |

## Build & run (development — Phase 1)

The adapter is read from a development location outside the app:

```
~/Library/Application Support/mediaremote-adapter/
├── bin/mediaremote-adapter.pl
└── build/MediaRemoteAdapter.framework
```

> ⚠️ **Do not** put the adapter under `~/Documents`, `~/Desktop`, or `~/Downloads`. Those
> are TCC-privacy-protected: a GUI app (unlike Terminal) can't read them, so the perl
> bridge fails with "Operation not permitted". `~/Library/Application Support` is fine.

To (re)build the adapter from source:

```sh
git clone https://github.com/ungive/mediaremote-adapter.git
cd mediaremote-adapter && mkdir build && cd build && cmake .. && cmake --build .
# then copy bin/ and build/ into ~/Library/Application Support/mediaremote-adapter/
```

Then open `playback-popup.xcodeproj` in Xcode and Run (⌘R). The path is overridable via the
`ADAPTER_ROOT` environment variable in the scheme.

Project settings already applied: **App Sandbox off** (required to spawn `perl`) and
**`LSUIElement` on** (menu-bar-only).

## Phase 2 — vendor the adapter (later)

Once stable, copy `mediaremote-adapter.pl` and `MediaRemoteAdapter.framework` into the app
bundle's resources (add a BSD-3 NOTICE), and change `AdapterLocation.default` to return
`.bundled`. No other code changes are needed — the bundle is always readable, so the TCC
caveat above disappears.
