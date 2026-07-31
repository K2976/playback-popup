# playback-popup

A tiny, native-feeling macOS menu-bar utility with a single purpose: whenever the
**currently playing media changes**, it briefly shows a clean "Now Playing" popup centered
just beneath the notch (or the menu bar, on Macs without one), then quietly fades away.

It's the feature that feels like Apple simply forgot to ship — no window, no clutter, no
configuration. Just a glanceable heads-up every time a new song or video starts.

<!-- Add a screenshot of the popup here, e.g.:
![playback-popup](docs/popup.png)
-->

> _Screenshot coming soon._

---

## What it does

When the currently playing media item changes — one song ends and the next begins, a
playlist advances, or a new video starts — a small translucent popup appears for about
2.5–3 seconds and then dismisses itself automatically. You never have to click anything;
it just shows up when something new starts playing.

The popup contains only:

- **Album artwork**
- **Song title**
- **Artist**
- **A single Play/Pause button**

Nothing else — no scrubber, no timers, no next/previous, no volume, no AirPlay.

## Features

- **Automatic** — appears on media changes without opening any menu or window.
- **Appears on the moments that matter** — when the media item changes and when you pause or
  resume the current track. Quiet metadata updates (like artwork loading in) don't re-trigger
  it.
- **No flicker on rapid changes** — if a new track starts while the popup is still up, the
  content updates in place and the timer restarts, rather than closing and reopening.
- **Native look & feel** — translucent vibrancy background, rounded (continuous-curve)
  corners, proper window shadow, native typography and spacing, smooth fade + slight
  downward slide on appearance, and full light/dark mode support.
- **Positioned like system UI** — horizontally centered beneath the notch (or the menu bar on
  non-notch Macs), on the active display, never overlapping the menu bar, notch, or Dock.
- **Menu-bar only** — runs as an accessory app (no Dock icon). The menu-bar icon is just an
  escape hatch; the popup does not depend on it.
- **Works across apps** — anything that reports to macOS's Now Playing system: Apple Music,
  Spotify, and media playing in Safari / Chrome (YouTube, etc.).
- **Lightweight** — event-driven and idle at rest; negligible CPU and memory. Fine to leave
  running all day.
- **Gracefully handles missing data** — falls back to a placeholder when artwork is
  unavailable and omits the artist line cleanly when there's no artist.
- **Fails safe** — if media monitoring can't start or stops working, the app keeps running
  and shows a clear "Media monitoring unavailable" status in the menu bar instead of
  crashing.

## Behavior at a glance

| Situation | What happens |
|-----------|--------------|
| Next song / video starts | Popup fades in, shows for ~2.7 s, fades out |
| New track while popup is visible | Content updates in place, timer restarts (no flicker) |
| Pause or resume the same track | Popup appears (on both pause and play) |
| Playback stops entirely | No popup; app stays idle |
| Artwork missing | Music-note placeholder |
| Artist missing | Artist line hidden, layout stays balanced |

---

## How it works

macOS has **no public API** for reading system-wide Now Playing information, and Apple
locked the private `MediaRemote.framework` behind an entitlement in **macOS 15.4+**. The one
technique that still works on macOS 26 (Tahoe) is the BSD-licensed
[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter): it invokes
`/usr/bin/perl` — an Apple binary that carries the required entitlement — to load a helper
framework that streams Now Playing changes as newline-delimited JSON. The app reads that
stream, detects genuine item changes, and drives the popup.

Because of this, the app is **not** Mac App Store distributable and must run un-sandboxed so
it can launch the Perl bridge. It's intended for personal/local use.

## Requirements

- macOS 15.4 or later (developed and tested on macOS 26 "Tahoe").
- Xcode.
- The `mediaremote-adapter` helper (see setup below).

## Build & run

The adapter (a Perl script + a helper framework) is read from a development location
outside the app:

```
~/Library/Application Support/mediaremote-adapter/
├── bin/mediaremote-adapter.pl
└── build/MediaRemoteAdapter.framework
```

To build the adapter from source:

```sh
git clone https://github.com/ungive/mediaremote-adapter.git
cd mediaremote-adapter && mkdir build && cd build && cmake .. && cmake --build .
# then copy bin/ and build/ into ~/Library/Application Support/mediaremote-adapter/
```

> ⚠️ **Don't** place the adapter under `~/Documents`, `~/Desktop`, or `~/Downloads`. Those
> folders are privacy-protected (TCC): a GUI app — unlike Terminal — can't read them, so the
> Perl bridge fails with "Operation not permitted". `~/Library/Application Support` works.

Then open `playback-popup.xcodeproj` in Xcode and Run (⌘R). Play or skip a track in Apple
Music (or a video in Safari/Chrome) to see the popup. The adapter path is overridable via
the `ADAPTER_ROOT` environment variable in the scheme.

Project settings already applied: **App Sandbox off** (required to spawn `perl`) and
**`LSUIElement` on** (menu-bar-only).

## Building & releasing

Beyond running from Xcode, the repo ships a small release pipeline that produces a standalone
`.app` and a distributable `.dmg` in a `dist/` folder — no Xcode needed to launch the result.

### Required tools

- **Xcode** (full install, not just Command Line Tools). The scripts locate it automatically.
- **[create-dmg](https://github.com/create-dmg/create-dmg)** — optional, for a polished DMG
  window with a drag-to-Applications shortcut. Install it once:

  ```sh
  ./scripts/bootstrap.sh        # installs create-dmg via Homebrew
  # or:  brew install create-dmg
  ```

  If it's not installed, the pipeline still works and falls back to plain `hdiutil`.

### One command

```sh
./scripts/release.sh
```

This builds a Release app and packages it into a DMG. When it finishes you'll have:

```
dist/
├── playback-popup.app     # standalone, ad-hoc-signed — double-click to launch
└── playback-popup.dmg     # share this; open it and drag the app to Applications
```

### Individual steps

```sh
./scripts/build-app.sh      # Release build → dist/playback-popup.app
./scripts/make-dmg.sh       # dist/playback-popup.app → dist/playback-popup.dmg
```

### Notes

- Builds are **ad-hoc signed** (no Apple Developer account, no notarization). On *your* Mac
  the app launches normally. On someone else's Mac, macOS Gatekeeper will block an unsigned
  app on first launch — they can **right-click the app → Open** (once), or run
  `xattr -dr com.apple.quarantine /Applications/playback-popup.app`.
- **Portability:** this DMG is currently for local use. The app reads the `mediaremote-adapter`
  from `~/Library/Application Support/mediaremote-adapter`, so on a Mac without that helper it
  opens but shows "media monitoring unavailable". To make it fully portable later, bundle the
  adapter into `Contents/Resources` (there's a marked extension point in
  [`scripts/build-app.sh`](scripts/build-app.sh)) and add Developer ID signing + notarization —
  the pipeline is organized so these slot in without restructuring.

## Customizing the look

Every visual constant — popup size, corner radius, artwork size, spacing, margins, animation
durations, and how long the popup stays on screen — lives in one place:
[`Appearance.swift`](playback-popup/Appearance.swift). Adjust values there without touching
the rest of the code.

## Project layout

| File | Responsibility |
|------|----------------|
| `playback_popupApp.swift` | App entry: `MenuBarExtra` + status icon/line reflecting health |
| `AppDelegate.swift` | Wires monitor → popup → controls; accessory activation policy |
| `AdapterLocation.swift` | Resolves the Perl script + framework paths (dev vs. bundled) |
| `AdapterProcess.swift` | Wrapper around the long-lived `perl … stream` subprocess |
| `NowPlayingMonitor.swift` | Parses the JSON stream, detects item changes, manages health/restart |
| `NowPlayingItem.swift` | Media snapshot + stable identity for change detection |
| `MediaRemoteControl.swift` | Sends the play/pause toggle command |
| `PopupController.swift` | Show / update-in-place / auto-dismiss, positioning, animations |
| `PopupPanel.swift` | Borderless, non-activating floating panel |
| `NowPlayingView.swift` | The SwiftUI popup content |
| `VisualEffectView.swift` | Native vibrancy + rounded corners |
| `Appearance.swift` | All UI constants |
| `Log.swift` | Unified-logging categories |

## Roadmap: bundling the adapter

Currently the adapter is read from a development path. A later step vendors the Perl script
and framework into the app bundle and flips `AdapterLocation.default` to `.bundled` — after
which the app is self-contained and the TCC caveat above no longer applies. No other code
changes are needed.

## Credits & license

Now Playing access is powered by [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
(BSD-3-Clause). Please consider starring that project — it's what makes this possible on
modern macOS.
