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

    /// Invoked when the pointer enters (`true`) or leaves (`false`) the popup.
    var onHoverChanged: (Bool) -> Void = { _ in }

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
            ArtworkView(image: viewModel.artwork, isPlaying: viewModel.isPlaying)

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
        .onHover { viewModel.onHoverChanged($0) }
    }
}

/// Album artwork with a graceful SF Symbol placeholder when none is available.
/// While media is playing, a small animated equalizer is overlaid on the
/// bottom — the same "now playing" indicator macOS/iOS use.
private struct ArtworkView: View {
    let image: NSImage?
    let isPlaying: Bool

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
        .overlay(alignment: .bottom) {
            if isPlaying {
                EqualizerView()
                    .frame(height: Appearance.artworkSize * 0.4)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.45)],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Appearance.artworkCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Appearance.artworkCornerRadius, style: .continuous)
                .strokeBorder(.primary.opacity(0.06))
        )
    }
}

/// A small animated equalizer — decorative bars that bounce while media plays.
/// MediaRemote exposes no waveform/FFT data, so this is an intentional
/// stylised indicator, not a real spectrum. Driven by `TimelineView(.animation)`
/// so it only animates while on screen; the popup is hidden (and this view torn
/// down) whenever nothing is playing, keeping the app idle at rest.
private struct EqualizerView: View {
    private let barCount = 4
    private let minScale: CGFloat = 0.25

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { i in
                        Capsule()
                            .fill(.white)
                            .frame(height: geo.size.height * barScale(i, t))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: CGFloat(barCount) * 5)
        .padding(.bottom, 4)
    }

    /// Per-bar height as a fraction of the available height: staggered sine waves
    /// so the bars never move in unison. Always within [minScale, 1].
    private func barScale(_ i: Int, _ t: Double) -> CGFloat {
        let speed = 4.0 + Double(i) * 0.9
        let phase = Double(i) * 1.7
        let v = (sin(t * speed + phase) + 1) / 2   // 0…1
        return minScale + CGFloat(v) * (1 - minScale)
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
