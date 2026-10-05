//
//  OnionSkin.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import CoreGraphics
import Foundation
import ImageIO

/// What decides how a frame lines up with the preview. Frames taken with a different camera, resolution,
/// rotation or mirroring don't line up with the current view, so a change to any of them starts a new
/// keyframe sequence.
nonisolated struct FrameGeometry: Codable, Equatable, Sendable {
    var cameraID: String
    var formatKey: String
    /// Clockwise degrees, as `Rotation.rawValue`.
    var rotation: Int
    var mirrored: Bool
}

/// The sequence the saved frames belong to, remembered across launches so resuming can tell whether
/// the last frames still line up.
nonisolated struct OnionSkinSequence: Codable, Equatable, Sendable {
    var root: String
    var geometry: FrameGeometry
}

/// Onion skinning: previous frames of a stop motion sequence drawn faintly over the live preview.
nonisolated enum OnionSkin {
    /// Frames kept in memory, whatever the layer setting, so raising it shows frames straight away.
    static let maxFrames = Preferences.onionSkinLayerRange.upperBound

    /// The size a saved frame has with this format and rotation. Rotation is baked into the pixels.
    static func frameSize(of format: CameraFormat, rotation: Rotation) -> CGSize {
        rotation.swapsDimensions
            ? CGSize(width: format.photoHeight, height: format.photoWidth)
            : CGSize(width: format.photoWidth, height: format.photoHeight)
    }

    /// Whether the last frames of the sequence named `root` can be shown again with the camera set up
    /// as `geometry`. With no record for that sequence (first use, or files from before the record was
    /// kept), the frame size check in `framesToLoad` is all there is to go on.
    static func canResume(_ sequence: OnionSkinSequence?, root: String, geometry: FrameGeometry) -> Bool {
        guard let sequence, sequence.root.lowercased() == root.lowercased() else { return true }
        return sequence.geometry == geometry
    }

    /// Which of a sequence's files (newest first, with their pixel sizes) to show again when onion
    /// skinning resumes. Frames of another size come from another camera or angle, so they start a new
    /// keyframe sequence: nothing older than the first such frame is used, and if the newest frame
    /// differs, none are.
    static func framesToLoad(_ files: [(url: URL, size: CGSize?)], frameSize: CGSize) -> [URL] {
        files.prefix(maxFrames)
            .prefix { $0.size == frameSize }
            .map(\.url)
    }

    /// Opacity of layer `index` (0 is the newest frame). The newest frame gets the full setting and each
    /// older one half the one before: 50, 25, 12.5, 6.25% at the 50% setting. Layers are stacked oldest
    /// on top, which gives each older frame a visibly smaller share of the picture (about 31, 20, 12
    /// and 6% at that setting, with the live view at 31%).
    static func opacity(ofLayer index: Int, newest: Double) -> Double {
        guard index >= 0 else { return 0 }
        return newest * pow(0.5, Double(index))
    }

    /// The pixel size of an image file, read from its header without decoding it.
    static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }

    /// A downscaled copy of an image, no larger than `maxPixelSize` on its long side.
    static func image(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
