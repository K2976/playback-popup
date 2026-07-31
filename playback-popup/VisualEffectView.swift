//
//  VisualEffectView.swift
//  playback-popup
//
//  The translucent, blurred, rounded background that makes the popup look like
//  a native system component. Used directly as the panel's contentView so the
//  window shadow follows the rounded (continuous-curve) shape.
//

import AppKit

final class PopupBackgroundView: NSVisualEffectView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        material = .popover
        blendingMode = .behindWindow
        state = .active

        wantsLayer = true
        layer?.cornerRadius = Appearance.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        updateBorderColor()
    }

    /// Border tint is resolved from a dynamic system colour, so refresh the
    /// cached CGColor whenever the effective appearance flips (dark/light).
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorderColor()
    }

    private func updateBorderColor() {
        let color = NSColor.labelColor.withAlphaComponent(Appearance.borderOpacity)
        effectiveAppearance.performAsCurrentDrawingAppearance { [weak self] in
            self?.layer?.borderColor = color.cgColor
        }
    }
}
