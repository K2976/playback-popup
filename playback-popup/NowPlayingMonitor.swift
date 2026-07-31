//
//  NowPlayingMonitor.swift
//  playback-popup
//
//  Owns the adapter subprocess, merges its diff-based JSON stream into a live
//  Now Playing state, and decides when the *media item* has actually changed.
//  Everything here runs on the main actor; only the raw stdout line assembly
//  happens off-thread inside AdapterProcess.
//
//  Presentation rules:
//   • Fire `onItemChanged(item, shouldPresent: true)` when the media *item*
//     changes (new `identity`) OR when the same item's play/pause state flips —
//     both pausing and resuming announce the current track.
//   • Fire `onItemChanged(item, shouldPresent: false)` for other same-item diffs
//     (e.g. late artwork) so a visible popup can refresh in place without
//     re-triggering.
//   • Suppress presentations for the very first snapshot after (re)starting, so
//     whatever is already playing/paused at launch doesn't announce itself.
//

import AppKit
import os

enum MonitorHealth: Equatable {
    case starting
    case running
    case unavailable
}

@MainActor
final class NowPlayingMonitor {

    // MARK: Callbacks

    /// `shouldPresent` is `true` when the popup should appear/restart (item
    /// change or play/pause toggle) and `false` for a quiet in-place refresh.
    var onItemChanged: ((NowPlayingItem, _ shouldPresent: Bool) -> Void)?
    var onHealthChange: ((MonitorHealth) -> Void)?

    private(set) var health: MonitorHealth = .starting {
        didSet {
            guard health != oldValue else { return }
            Log.monitor.info("health -> \(String(describing: self.health), privacy: .public)")
            onHealthChange?(health)
        }
    }

    // MARK: Tuning (behavioural, not UI — kept local to the monitor)

    private let debounceMilliseconds = 200
    private let startupSuppression: TimeInterval = 1.2
    private let maxConsecutiveRestarts = 5
    private let stableRunSeconds: TimeInterval = 20

    // MARK: State

    private var adapter: AdapterProcess?
    private var restartTask: Task<Void, Never>?
    private var isStopping = false

    private var mergedState: [String: Any] = [:]
    private var lastIdentity: String?
    private var lastPlaying: Bool?

    private var restartCount = 0
    private var lastStartTime = Date.distantPast
    private var startupSuppressionDeadline = Date.distantPast

    // Artwork decode cache — avoids re-decoding a large base64 blob on every
    // unrelated diff for the same track.
    private var cachedArtworkKey: String?
    private var cachedArtwork: NSImage?

    // MARK: Lifecycle

    func start() {
        isStopping = false
        restartTask?.cancel()
        restartTask = nil

        guard let paths = AdapterLocation.default.resolve() else {
            Log.monitor.error("adapter not found — monitoring unavailable")
            health = .unavailable
            return
        }

        health = .starting
        mergedState = [:]
        lastStartTime = Date()
        startupSuppressionDeadline = Date().addingTimeInterval(startupSuppression)

        let process = AdapterProcess(
            paths: paths,
            arguments: ["stream", "--debounce=\(debounceMilliseconds)"],
            onLine: { [weak self] line in
                guard let self else { return }
                Task { @MainActor in self.handleLine(line) }
            },
            onExit: { [weak self] status in
                guard let self else { return }
                Task { @MainActor in self.handleExit(status) }
            }
        )

        do {
            try process.start()
            adapter = process
        } catch {
            Log.monitor.error("failed to launch adapter: \(error, privacy: .public)")
            adapter = nil
            scheduleRestart()
        }
    }

    /// Stop monitoring and tear down the subprocess (used on quit).
    func stop() {
        isStopping = true
        restartTask?.cancel()
        restartTask = nil
        adapter?.stop()
        adapter = nil
    }

    /// Manual recovery, surfaced in the menu when monitoring is unavailable.
    func retry() {
        restartCount = 0
        stop()
        start()
    }

    // MARK: Stream handling

    private func handleLine(_ line: String) {
        // Any successful line means the stream is alive.
        if health != .running { health = .running }
        if restartCount > 0, Date().timeIntervalSince(lastStartTime) > stableRunSeconds {
            restartCount = 0
        }

        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["type"] as? String) == "data",
              let payload = object["payload"] as? [String: Any] else {
            return
        }

        let isDiff = (object["diff"] as? Bool) ?? false
        if isDiff {
            for (key, value) in payload {
                if value is NSNull {
                    mergedState.removeValue(forKey: key)
                } else {
                    mergedState[key] = value
                }
            }
        } else {
            // Full snapshot replaces everything; empty payload == no media.
            mergedState = payload.filter { !($0.value is NSNull) }
        }

        evaluate()
    }

    private func evaluate() {
        guard let title = mergedState["title"] as? String, !title.isEmpty else {
            // No valid media (stopped/cleared). Keep `lastIdentity` so resuming
            // the same track later doesn't announce itself as new.
            return
        }

        let item = makeItem(title: title)
        let isNewItem = item.identity != lastIdentity
        // A play/pause flip on the *same* item should also announce the track.
        // (`lastPlaying == nil` guards the very first observation.)
        let playbackToggled = !isNewItem
            && lastPlaying != nil
            && item.isPlaying != lastPlaying

        lastIdentity = item.identity
        lastPlaying = item.isPlaying

        guard isNewItem || playbackToggled else {
            // Other same-item diffs (e.g. late artwork): quiet in-place refresh.
            onItemChanged?(item, false)
            return
        }

        // Swallow whatever is already playing/paused when the stream (re)started.
        guard Date() >= startupSuppressionDeadline else {
            Log.monitor.debug("seed (suppressed) \(item.title, privacy: .public)")
            return
        }

        Log.monitor.info("present \(item.title, privacy: .public) — playing=\(item.isPlaying) new=\(isNewItem)")
        onItemChanged?(item, true)
    }

    private func makeItem(title: String) -> NowPlayingItem {
        let artist = nonEmpty(mergedState["artist"] as? String)
        let album = nonEmpty(mergedState["album"] as? String)
        let isPlaying = (mergedState["playing"] as? Bool) ?? false
        // Prefer the owning app (e.g. Safari) over the media process (WebKit GPU).
        let bundleID = (mergedState["parentApplicationBundleIdentifier"] as? String)
            ?? (mergedState["bundleIdentifier"] as? String)

        return NowPlayingItem(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            artwork: currentArtwork(),
            bundleIdentifier: bundleID
        )
    }

    private func currentArtwork() -> NSImage? {
        guard let base64 = mergedState["artworkData"] as? String, !base64.isEmpty else {
            return nil
        }
        if base64 == cachedArtworkKey { return cachedArtwork }
        let image = Data(base64Encoded: base64).flatMap { NSImage(data: $0) }
        cachedArtworkKey = base64
        cachedArtwork = image
        return image
    }

    // MARK: Recovery

    private func handleExit(_ status: Int32) {
        guard !isStopping else { return }
        Log.monitor.notice("adapter exited (status \(status)); scheduling restart")
        adapter = nil
        scheduleRestart()
    }

    private func scheduleRestart() {
        restartCount += 1
        guard restartCount <= maxConsecutiveRestarts else {
            health = .unavailable
            return
        }

        // Exponential backoff, capped: 1, 2, 4, 8, 8 …
        let delay = min(pow(2.0, Double(restartCount - 1)), 8.0)
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, !self.isStopping else { return }
            self.start()
        }
    }

    // MARK: Helpers

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
