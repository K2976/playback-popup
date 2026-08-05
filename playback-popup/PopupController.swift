//
//  PopupController.swift
//  playback-popup
//
//  Owns the single reused popup panel and its show / update / dismiss
//  lifecycle. Behaviour matches the spec:
//   • New item while hidden → fade + slide in, then auto-dismiss after a delay.
//   • New item while visible → update content in place and restart the timer
//     (no re-animation, no flicker).
//   • Same item update (late artwork, playback toggle) → refresh in place only
//     if currently visible; never re-shows or extends the timer.
//

import AppKit
import QuartzCore
import os

@MainActor
final class PopupController {

    private let viewModel = PopupViewModel()
    private lazy var panel = PopupPanel(viewModel: viewModel)

    private var isVisible = false
    private var isHovered = false
    private var dismissTask: Task<Void, Never>?
    /// Invalidates in-flight fade-out completions when the popup is revived.
    private var dismissToken = 0

    init() {
        // While the pointer is over the popup, keep it up; dismiss once it leaves.
        viewModel.onHoverChanged = { [weak self] hovering in
            self?.handleHover(hovering)
        }
    }

    /// Wire up the Play/Pause action. The tap flips the button optimistically
    /// for instant feedback; the real state is confirmed by the next stream
    /// update.
    func setTogglePlayPauseHandler(_ handler: @escaping () -> Void) {
        viewModel.onTogglePlayPause = { [weak self] in
            self?.viewModel.isPlaying.toggle()
            handler()
        }
    }

    /// Present or update the popup for a media item.
    func present(_ item: NowPlayingItem, shouldPresent: Bool) {
        guard shouldPresent else {
            // In-place refresh only matters while the popup is on screen.
            if isVisible { viewModel.update(with: item) }
            return
        }

        viewModel.update(with: item)

        if isVisible {
            // Cancel any pending fade-out, snap back to full opacity, restart.
            // Re-target the frame so a track change follows you to whatever
            // screen you're now on (the popup already joins all Spaces).
            Log.popup.info("update in place: \(item.title, privacy: .public)")
            dismissToken += 1
            panel.setFrame(targetFrame(), display: true)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
            scheduleDismiss()
        } else {
            Log.popup.info("show: \(item.title, privacy: .public)")
            showAnimated()
            scheduleDismiss()
        }
    }

    // MARK: - Show / dismiss

    private func showAnimated() {
        let finalFrame = targetFrame()
        var startFrame = finalFrame
        startFrame.origin.y += Appearance.slideOffset   // start slightly higher…

        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        isVisible = true
        // Fresh presentation: clear any hover state left stale by the previous
        // popup dismissing out from under the cursor (`onHover(false)` may not
        // fire then). `.onHover` re-asserts true if the pointer is over the new one.
        isHovered = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Appearance.fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)   // …slide down.
        }
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        // Stay up as long as the pointer is over the popup; the timer (re)starts
        // when the pointer leaves (see `handleHover`).
        guard !isHovered else { return }
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Appearance.displayDuration))
            guard let self, !Task.isCancelled else { return }
            self.dismissAnimated()
        }
    }

    /// Keep the popup up while hovered; restart a fresh full-duration timer once
    /// the pointer leaves. Also rescues a popup that's mid-fade-out.
    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
        guard isVisible else { return }
        if hovering {
            dismissTask?.cancel()
            dismissToken += 1   // invalidate any in-flight fade-out completion
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
        } else {
            scheduleDismiss()
        }
    }

    private func dismissAnimated() {
        guard isVisible else { return }
        dismissToken += 1
        let token = dismissToken

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Appearance.fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // NSAnimationContext completion is delivered on the main thread.
            MainActor.assumeIsolated {
                guard let self, token == self.dismissToken else { return }
                self.panel.orderOut(nil)
                self.isVisible = false
            }
        })
    }

    // MARK: - Positioning

    /// The popup's on-screen frame, centered beneath the notch / menu bar of the
    /// active display. All placement math lives in `PopupPositioner`.
    private func targetFrame() -> NSRect {
        let size = CGSize(width: Appearance.popupWidth, height: Appearance.popupHeight)
        guard let screen = PopupPositioner.activeScreen else {
            // No display reported (extremely unlikely) — keep it on-screen.
            return NSRect(origin: .zero, size: size)
        }
        return PopupPositioner.frame(for: size, on: screen)
    }
}
