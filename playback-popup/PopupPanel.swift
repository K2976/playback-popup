//
//  PopupPanel.swift
//  playback-popup
//
//  A borderless, non-activating floating panel that hosts the Now Playing view
//  over the vibrancy background. It never steals focus from the frontmost app,
//  floats above normal windows, and appears on every Space.
//

import AppKit
import SwiftUI

final class PopupPanel: NSPanel {

    init(viewModel: PopupViewModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0,
                                width: Appearance.popupWidth,
                                height: Appearance.popupHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary,
                              .fullScreenAuxiliary, .ignoresCycle]

        let background = PopupBackgroundView(frame: .zero)
        let hosting = FirstMouseHostingView(rootView: NowPlayingView(viewModel: viewModel))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        contentView = background
    }

    // Allow interaction with the Play/Pause button without activating the app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// NSHostingView that responds to the very first click even when the panel is
/// not yet key — so tapping Play/Pause works on the first try.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
