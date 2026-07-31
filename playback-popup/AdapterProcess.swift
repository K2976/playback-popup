//
//  AdapterProcess.swift
//  playback-popup
//
//  Thin, non-isolated wrapper around the long-lived `/usr/bin/perl … stream`
//  subprocess. It owns the Process + Pipe, reassembles stdout into complete
//  newline-delimited JSON lines on the pipe's background delivery queue, and
//  forwards each line (and process exit) via @Sendable callbacks. Callers hop
//  back to the main actor themselves.
//
//  This type is deliberately `nonisolated` (the project defaults new types to
//  @MainActor) because the readability handler runs off the main thread.
//

import Foundation

nonisolated final class AdapterProcess: @unchecked Sendable {

    private let process = Process()
    private let outPipe = Pipe()

    /// Only ever mutated inside the pipe's serial readability handler.
    private var buffer = Data()
    private var stopped = false

    private let onLine: @Sendable (String) -> Void
    private let onExit: @Sendable (Int32) -> Void

    init(paths: AdapterPaths,
         arguments: [String],
         onLine: @escaping @Sendable (String) -> Void,
         onExit: @escaping @Sendable (Int32) -> Void) {
        self.onLine = onLine
        self.onExit = onExit

        process.executableURL = AdapterLocation.perlURL
        process.arguments = [paths.script.path, paths.framework.path] + arguments
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice
    }

    /// Launch the subprocess and begin streaming. Throws if perl can't start.
    func start() throws {
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.buffer.append(data)
            self.drainLines()
        }

        process.terminationHandler = { [weak self] proc in
            guard let self, !self.stopped else { return }
            self.outPipe.fileHandleForReading.readabilityHandler = nil
            self.onExit(proc.terminationStatus)
        }

        try process.run()
    }

    /// Stop the subprocess and detach all handlers. Safe to call repeatedly.
    func stop() {
        stopped = true
        process.terminationHandler = nil
        outPipe.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            process.terminate()
        }
    }

    // MARK: - Line reassembly

    private func drainLines() {
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            guard !lineData.isEmpty,
                  let line = String(data: lineData, encoding: .utf8) else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                onLine(trimmed)
            }
        }
    }
}
