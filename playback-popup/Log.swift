//
//  Log.swift
//  playback-popup
//
//  Lightweight structured logging via the unified logging system. Useful for a
//  background utility — especially for diagnosing when media monitoring becomes
//  unavailable — while staying effectively free at runtime when not observed.
//
//  View live:  log stream --predicate 'subsystem == "K2976.playback-popup"'
//

import os

enum Log {
    private static let subsystem = "K2976.playback-popup"

    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let popup = Logger(subsystem: subsystem, category: "popup")
}
