//
//  Log.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import os

/// Unified logging. Read with:
/// `log show --last 10m --predicate 'subsystem == "com.ideocentric.fauxto"'`
nonisolated enum Log {
    static let lifecycle = Logger(subsystem: "com.ideocentric.fauxto", category: "lifecycle")
    static let capture = Logger(subsystem: "com.ideocentric.fauxto", category: "capture")
}
