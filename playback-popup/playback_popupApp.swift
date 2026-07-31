//
//  playback_popupApp.swift
//  playback-popup
//
//  Menu-bar-only app entry point. The MenuBarExtra is just an access/status
//  affordance — the popup appears automatically on media changes regardless of
//  whether the menu is ever opened. Its icon and status line reflect the
//  monitor's health so failures are visible without crashing anything.
//

import SwiftUI

@main
struct playback_popupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            StatusMenuContent(health: appDelegate.health) {
                appDelegate.retryMonitoring()
            }
        } label: {
            Image(systemName: appDelegate.health == .unavailable
                  ? "exclamationmark.triangle.fill"
                  : "music.note")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Minimal status menu: app name, a monitoring-status line (the graceful-
/// failure indicator), and Quit.
private struct StatusMenuContent: View {
    let health: MonitorHealth
    let retry: () -> Void

    var body: some View {
        Text("playback-popup")

        Divider()

        switch health {
        case .starting:
            Text("Starting…")
        case .running:
            Text("Monitoring active")
        case .unavailable:
            Text("Media monitoring unavailable")
            Button("Try Again", action: retry)
        }

        Divider()

        Button("Quit playback-popup") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
