//
//  NowPlayingItem.swift
//  playback-popup
//
//  Immutable snapshot of the currently playing media item, built from the
//  merged adapter state. `identity` is what drives "did the media item change?"
//  detection — it deliberately excludes volatile fields like playback state and
//  elapsed time so that pausing/resuming the same track is never treated as a
//  new item.
//

import AppKit

struct NowPlayingItem {
    let title: String
    let artist: String?
    let album: String?
    let isPlaying: Bool
    let artwork: NSImage?
    let bundleIdentifier: String?

    /// Stable identity for change detection. Two snapshots of the same media
    /// item share an identity even if playback state or artwork differ.
    var identity: String {
        [title, artist ?? "", album ?? "", bundleIdentifier ?? ""]
            .joined(separator: "\u{1}")
    }
}
