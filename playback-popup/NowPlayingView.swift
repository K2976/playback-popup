//
//  NowPlayingView.swift
//  playback-popup
//
//  The popup's SwiftUI content: album artwork, title, artist, and a single
//  centred Play/Pause button — nothing else. Background is intentionally clear;
//  the vibrancy comes from the NSVisualEffectView behind it. All sizing pulls
//  from `Appearance`.
//

import SwiftUI
import Combine

/// Observable backing store for the popup. Updated in place so track changes
/// never recreate the view hierarchy (no flicker).
@MainActor
final class PopupViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var artist: String?
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false

    /// Invoked when the user taps the Play/Pause button.
    var onTogglePlayPause: () -> Void = {}

    func update(with item: NowPlayingItem) {
        title = item.title
        artist = item.artist
        artwork = item.artwork
        isPlaying = item.isPlaying
    }
}

struct NowPlayingView: View {
    @ObservedObject var viewModel: PopupViewModel

    var body: some View {
        HStack(spacing: Appearance.horizontalSpacing) {
            ArtworkView(image: viewModel.artwork)

            VStack(alignment: .leading, spacing: Appearance.verticalSpacing) {
                Text(viewModel.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let artist = viewModel.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                PlayPauseButton(isPlaying: viewModel.isPlaying) {
                    viewModel.onTogglePlayPause()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Appearance.buttonTopSpacing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Appearance.contentPadding)
        .frame(width: Appearance.popupWidth, height: Appearance.popupHeight)
    }
}

/// Album artwork with a graceful SF Symbol placeholder when none is available.
private struct ArtworkView: View {
    let image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.system(size: Appearance.artworkSize * 0.4, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: Appearance.artworkSize, height: Appearance.artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: Appearance.artworkCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Appearance.artworkCornerRadius, style: .continuous)
                .strokeBorder(.primary.opacity(0.06))
        )
    }
}

/// The one interactive control. Uses a native symbol-replace transition so the
/// glyph swap feels like system UI.
private struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: Appearance.playButtonPointSize, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Appearance.playButtonPointSize + 12,
                       height: Appearance.playButtonPointSize + 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
