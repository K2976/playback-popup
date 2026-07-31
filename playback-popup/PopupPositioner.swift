//
//  PopupPositioner.swift
//  playback-popup
//
//  Owns all popup-placement math in one place. The popup is centered
//  horizontally on the active display and tucked just below the menu bar —
//  which, on MacBooks with a notch, is directly beneath the notch: macOS makes
//  the menu bar exactly as tall as the notch, so a display's *visible frame*
//  already begins below it. The result mirrors where native system UI sits.
//
//  Fully dynamic — nothing is hardcoded. It adapts automatically to screen
//  resolution, Retina / non-Retina scale (AppKit works in points, so scale is
//  handled for us), external monitors, notch vs. non-notch displays, differing
//  menu-bar heights, and any popup size.
//

import AppKit

enum PopupPositioner {

    /// The display the user is currently working on.
    ///
    /// Prefers the screen that owns the key window (Apple's definition of the
    /// "main" screen — i.e. where the active session is focused), then the screen
    /// under the pointer, then the first screen. Deliberately never assumes the
    /// built-in display.
    static var activeScreen: NSScreen? {
        if let focused = NSScreen.main { return focused }
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.screens.first
    }

    /// Target frame for a popup of `size` on `screen`: horizontally centered on
    /// the physical display and sitting `Appearance.topGap` points below the menu
    /// bar / notch. Never overlaps the menu bar, the notch, or the Dock.
    static func frame(for size: CGSize, on screen: NSScreen) -> NSRect {
        // The notch is centered on the *full* display, so centering on the full
        // frame (not the visible frame, which the Dock can shrink/shift) is what
        // keeps the popup aligned under the notch.
        let display = screen.frame

        // The visible frame's top edge is the bottom of the menu bar on every
        // kind of display — and, on notched Macs, the bottom of the notch.
        let menuBarBottom = screen.visibleFrame.maxY

        let x = display.midX - size.width / 2
        let y = menuBarBottom - Appearance.topGap - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
