//
//  Appearance.swift
//  playback-popup
//
//  Single source of truth for every UI constant used by the popup.
//  Centralised here so sizing, spacing, timing and radii can be tuned in one
//  place without hunting through the view code. This is intentionally *not* a
//  theming system — just named constants to keep the UI maintainable.
//

import SwiftUI

enum Appearance {

    // MARK: Popup size

    /// Overall popup dimensions. Kept fixed so positioning and animations are
    /// predictable and the layout never jumps as metadata changes.
    static let popupWidth: CGFloat = 280
    static let popupHeight: CGFloat = 104
    static let cornerRadius: CGFloat = 18

    // MARK: Artwork

    static let artworkSize: CGFloat = 60
    static let artworkCornerRadius: CGFloat = 8

    // MARK: Content layout

    static let contentPadding = EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16)
    static let horizontalSpacing: CGFloat = 14
    static let verticalSpacing: CGFloat = 2
    static let buttonTopSpacing: CGFloat = 8
    static let playButtonPointSize: CGFloat = 20

    // MARK: Positioning

    /// Vertical gap between the bottom of the menu bar / notch and the top of the
    /// popup, so it reads as intentional rather than glued to the menu bar.
    /// See `PopupPositioner` for how the popup is centered beneath the notch.
    static let topGap: CGFloat = 10

    // MARK: Animation & timing

    static let fadeInDuration: TimeInterval = 0.28
    static let fadeOutDuration: TimeInterval = 0.36
    /// How far (points) the popup slides down while fading in.
    static let slideOffset: CGFloat = 10
    /// How long the popup stays fully visible before auto-dismissing.
    static let displayDuration: TimeInterval = 2.7

    // MARK: Materials

    /// Subtle hairline border opacity, layered over the vibrancy material.
    static let borderOpacity: CGFloat = 0.08
}
