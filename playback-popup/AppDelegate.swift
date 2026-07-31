//
//  AppDelegate.swift
//  playback-popup
//
//  Wires the pieces together and owns their lifetime. Exposes `health` as an
//  observable so the menu bar can reflect monitoring status. Runs as an
//  accessory (menu-bar-only) app.
//

import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    /// Mirrors the monitor's health so the MenuBarExtra can react to it.
    @Published private(set) var health: MonitorHealth = .starting

    private let monitor = NowPlayingMonitor()
    private let popup = PopupController()
    private let control = MediaRemoteControl()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        popup.setTogglePlayPauseHandler { [weak self] in
            self?.control.togglePlayPause()
        }

        monitor.onItemChanged = { [weak self] item, isNewItem in
            self?.popup.present(item, isNewItem: isNewItem)
        }
        monitor.onHealthChange = { [weak self] health in
            self?.health = health
        }

        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    /// Manual retry surfaced in the menu when monitoring is unavailable.
    func retryMonitoring() {
        monitor.retry()
    }
}
