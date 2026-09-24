//
//  Log.swift
//  fauxto
//

import os

/// Unified logging. Read with:
/// `log show --last 10m --predicate 'subsystem == "com.ideocentric.fauxto"'`
nonisolated enum Log {
    static let lifecycle = Logger(subsystem: "com.ideocentric.fauxto", category: "lifecycle")
    static let capture = Logger(subsystem: "com.ideocentric.fauxto", category: "capture")
}
