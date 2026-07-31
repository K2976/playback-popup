//
//  MediaRemoteControl.swift
//  playback-popup
//
//  Sends one-shot MediaRemote commands (just play/pause toggle for this app)
//  through the same perl bridge. Fire-and-forget: failures are swallowed so a
//  broken adapter never destabilises the UI.
//

import Foundation

@MainActor
final class MediaRemoteControl {

    /// MediaRemote command IDs (see the adapter's `send` table).
    private enum Command: Int {
        case togglePlayPause = 2
    }

    func togglePlayPause() {
        send(.togglePlayPause)
    }

    private func send(_ command: Command) {
        guard let paths = AdapterLocation.default.resolve() else { return }

        let process = Process()
        process.executableURL = AdapterLocation.perlURL
        process.arguments = [paths.script.path, paths.framework.path,
                             "send", String(command.rawValue)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
