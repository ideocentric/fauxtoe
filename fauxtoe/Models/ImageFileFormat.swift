//
//  ImageFileFormat.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The file formats a photo can be written in.
nonisolated enum ImageFileFormat: String, CaseIterable, Identifiable, Sendable {
    case heic
    case jpeg
    case png
    case tiff

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heic: "HEIC"
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .tiff: "TIFF"
        }
    }

    var utType: UTType {
        switch self {
        case .heic: .heic
        case .jpeg: .jpeg
        case .png: .png
        case .tiff: .tiff
        }
    }

    var fileExtension: String {
        switch self {
        case .heic: "heic"
        case .jpeg: "jpg"
        case .png: "png"
        case .tiff: "tiff"
        }
    }

    /// Whether the quality setting applies to this format.
    var isLossy: Bool { self == .heic || self == .jpeg }

    /// Formats ImageIO can encode on this Mac. HEIC needs a hardware or software HEVC encoder.
    static var available: [ImageFileFormat] {
        let writable = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        return allCases.filter { writable.contains($0.utType.identifier) }
    }
}

/// Clockwise rotation applied to the preview and to saved photos, for cameras mounted sideways or upside down.
nonisolated enum Rotation: Int, CaseIterable, Identifiable, Sendable {
    case none = 0
    case clockwise90 = 90
    case upsideDown = 180
    case clockwise270 = 270

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .none: String(localized: "None", comment: "No rotation")
        case .clockwise90: String(localized: "90° Clockwise")
        case .upsideDown: "180°"
        case .clockwise270: String(localized: "90° Counterclockwise")
        }
    }

    var rotatedRight: Rotation { Rotation(rawValue: (rawValue + 90) % 360)! }
    var rotatedLeft: Rotation { Rotation(rawValue: (rawValue + 270) % 360)! }

    /// True when width and height trade places.
    var swapsDimensions: Bool { self == .clockwise90 || self == .clockwise270 }
}
