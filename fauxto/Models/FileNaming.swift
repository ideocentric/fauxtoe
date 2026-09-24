//
//  FileNaming.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import Foundation

/// How photos are named when the user doesn't type a name.
nonisolated enum NamingScheme: String, CaseIterable, Identifiable, Sendable {
    /// The `{date} {time}` style template.
    case template
    /// A fixed root plus a counter: imagename-001, imagename-002...
    case numbered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .template: "Date and time"
        case .numbered: "Name and number"
        }
    }
}

/// Builds file names from the naming template and keeps saves from overwriting existing files.
nonisolated enum FileNaming {
    static let defaultTemplate = "fauxto {date} at {time}"

    /// Tokens the template understands, for display in Settings.
    static let tokens: [(token: String, meaning: String)] = [
        ("{date}", "Date, e.g. 2026-09-23"),
        ("{time}", "Time, e.g. 14.05.32"),
        ("{n}", "Sequence number, e.g. 0007"),
        ("{camera}", "Camera name"),
    ]

    static func render(template: String, date: Date, sequence: Int, camera: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH.mm.ss"

        let rendered = template
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: date))
            .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: date))
            .replacingOccurrences(of: "{n}", with: String(format: "%04d", sequence))
            .replacingOccurrences(of: "{camera}", with: camera)
        let clean = sanitize(rendered)
        return clean.isEmpty ? sanitize(render(template: defaultTemplate, date: date, sequence: sequence, camera: camera)) : clean
    }

    /// Makes a user-typed name safe to use as a file name: no path separators, no leading dots, no
    /// surrounding whitespace, and no extension the user may have typed out of habit.
    static func sanitize(_ name: String, stripping extensions: [String] = ImageFileFormat.allCases.map(\.fileExtension) + ["jpeg", "tif"]) -> String {
        var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = result.lowercased()
        if let ext = extensions.first(where: { lower.hasSuffix("." + $0) }) {
            result = String(result.dropLast(ext.count + 1))
        }
        result = result
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .components(separatedBy: .controlCharacters).joined()
        while result.hasPrefix(".") { result.removeFirst() }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns `folder/baseName.ext`, or `folder/baseName 2.ext`, `baseName 3.ext`... if that exists.
    static func uniqueURL(in folder: URL, baseName: String, fileExtension: String,
                          fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2
        while fileExists(candidate) {
            candidate = folder.appendingPathComponent("\(baseName) \(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }

    static let defaultRoot = "image"

    /// `root-001`. Numbers keep growing past 999 (`root-1000`).
    static func numberedName(root: String, number: Int) -> String {
        "\(root)-\(String(format: "%03d", number))"
    }

    /// The highest N among files named `root-N.<ext>`, compared case-insensitively, or 0 if none.
    /// Numbering continues from what is already in the folder, so it survives relaunches.
    static func highestNumber(root: String, in fileNames: [String]) -> Int {
        let prefix = root.lowercased() + "-"
        return fileNames.compactMap { fileName -> Int? in
            let stem = (fileName as NSString).deletingPathExtension.lowercased()
            guard stem != fileName.lowercased(), stem.hasPrefix(prefix) else { return nil }
            let digits = stem.dropFirst(prefix.count)
            guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int(digits)
        }.max() ?? 0
    }

    /// Suggests the next name in a series: "pcb-top-01" becomes "pcb-top-02", "board 9" becomes
    /// "board 10", and a name without a trailing number gets " 2".
    static func incremented(_ name: String) -> String {
        let digits = name.reversed().prefix(while: \.isNumber)
        guard !digits.isEmpty, let value = Int(String(digits.reversed())) else {
            return name + " 2"
        }
        let stem = name.dropLast(digits.count)
        let next = String(value + 1)
        let padded = String(repeating: "0", count: max(0, digits.count - next.count)) + next
        return stem + padded
    }
}
