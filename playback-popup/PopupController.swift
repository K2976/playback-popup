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
    private var dismissTask: Task<Void, Never>?
    /// Invalidates in-flight fade-out completions when the popup is revived.
    private var dismissToken = 0

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
            Log.popup.info("update in place: \(item.title, privacy: .public)")
            dismissToken += 1
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
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Appearance.displayDuration))
            guard let self, !Task.isCancelled else { return }
            self.dismissAnimated()
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
