//
//  NewFile.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import Foundation

/// Writes a file only where nothing exists yet, without ever leaving a half-written one.
nonisolated enum NewFile {
    /// Writes `data` to `url` if nothing is there. The data goes to a hidden temporary file in the same
    /// folder first and is then moved into place with an exclusive rename, which fails rather than
    /// replace a file that appeared since the name was chosen. Throws `POSIXError(.EEXIST)` in that
    /// case, so the caller can pick another name. (`Data.write` can't do both: `.atomic` overwrites,
    /// and `.withoutOverwriting` can't be combined with it.)
    static func write(_ data: Data, to url: URL) throws {
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).fauxtoe-partial")
        try data.write(to: temporary, options: .withoutOverwriting)
        let failure: Int32 = temporary.withUnsafeFileSystemRepresentation { from in
            url.withUnsafeFileSystemRepresentation { to in
                guard let from, let to else { return EINVAL }
                return renamex_np(from, to, UInt32(RENAME_EXCL)) == 0 ? 0 : errno
            }
        }
        guard failure != 0 else { return }
        try? FileManager.default.removeItem(at: temporary)
        throw POSIXError(POSIXErrorCode(rawValue: failure) ?? .EIO)
    }

    /// Writes `data` under `baseName` in `folder`, adding a number if the name is taken, and returns
    /// where it went. A name taken between choosing it and writing is skipped like any other.
    static func write(_ data: Data, in folder: URL, baseName: String, fileExtension: String) throws -> URL {
        for _ in 0..<20 {
            let url = FileNaming.uniqueURL(in: folder, baseName: baseName, fileExtension: fileExtension)
            do {
                try write(data, to: url)
                return url
            } catch let error as POSIXError where error.code == .EEXIST {
                continue
            }
        }
        throw POSIXError(.EEXIST)
    }
}
