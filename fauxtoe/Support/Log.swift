//
//  Log.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import os

/// Unified logging. Read with:
/// `log show --last 10m --predicate 'subsystem == "com.ideocentric.fauxtoe"'`
nonisolated enum Log {
    static let lifecycle = Logger(subsystem: "com.ideocentric.fauxtoe", category: "lifecycle")
    static let capture = Logger(subsystem: "com.ideocentric.fauxtoe", category: "capture")
}
