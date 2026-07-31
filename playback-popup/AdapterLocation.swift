//
//  AdapterLocation.swift
//  playback-popup
//
//  The single seam between "development" and "bundled" adapter integration.
//
//  Phase 1 (current): the mediaremote-adapter perl script + helper framework
//  live outside the app, at `developmentRoot` (or an $ADAPTER_ROOT override).
//  Phase 2 (later): copy those two files into the app bundle and flip
//  `default` to `.bundled`. Nothing else in the codebase needs to change.
//

import Foundation

/// Resolved on-disk locations the perl bridge needs.
struct AdapterPaths {
    let script: URL      // mediaremote-adapter.pl
    let framework: URL   // MediaRemoteAdapter.framework
}

enum AdapterLocation {
    /// Read the adapter from a checked-out + built copy on disk.
    case development(root: URL)
    /// Read the adapter from resources bundled inside the app (Phase 2).
    case bundled

    // MARK: Phase 1 development location

    /// Where the built adapter lives during development. Kept out of
    /// TCC-protected locations (~/Documents, ~/Desktop, ~/Downloads) so the
    /// GUI app — unlike Terminal — is allowed to read it. In Phase 2 these
    /// files move into the app bundle, which needs no such exception.
    /// Overridable at runtime via the `ADAPTER_ROOT` env var.
    private static var developmentRoot: String {
        (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Application Support/mediaremote-adapter")
    }

    /// The location the app uses. Change this one line in Phase 2.
    static var `default`: AdapterLocation {
        if let override = ProcessInfo.processInfo.environment["ADAPTER_ROOT"],
           !override.isEmpty {
            return .development(root: URL(fileURLWithPath: override))
        }
        return .development(root: URL(fileURLWithPath: developmentRoot))
    }

    /// Absolute path to the entitled interpreter that loads the framework.
    /// `nonisolated` so the off-main `AdapterProcess` can read it.
    nonisolated static let perlURL = URL(fileURLWithPath: "/usr/bin/perl")

    /// Resolve concrete paths, or `nil` if the adapter can't be found — in
    /// which case the monitor reports itself unavailable rather than crashing.
    func resolve() -> AdapterPaths? {
        let fm = FileManager.default
        switch self {
        case .development(let root):
            let script = root.appendingPathComponent("bin/mediaremote-adapter.pl")
            let framework = root.appendingPathComponent("build/MediaRemoteAdapter.framework")
            guard fm.fileExists(atPath: script.path),
                  fm.fileExists(atPath: framework.path) else { return nil }
            return AdapterPaths(script: script, framework: framework)

        case .bundled:
            guard let script = Bundle.main.url(forResource: "mediaremote-adapter",
                                               withExtension: "pl"),
                  let framework = Bundle.main.url(forResource: "MediaRemoteAdapter",
                                                  withExtension: "framework") else {
                return nil
            }
            return AdapterPaths(script: script, framework: framework)
        }
    }
}
