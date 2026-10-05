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

    /// Which of a sequence's files (newest first, with their pixel sizes) to show again when onion
    /// skinning resumes. Frames of another size come from another camera or angle, so they start a new
    /// keyframe sequence: nothing older than the first such frame is used, and if the newest frame
    /// differs, none are.
    static func framesToLoad(_ files: [(url: URL, size: CGSize?)], frameSize: CGSize) -> [URL] {
        files.prefix(maxFrames)
            .prefix { $0.size == frameSize }
            .map(\.url)
    }

    /// Opacity of layer `index` (0 is the newest frame) when `count` layers are shown. The newest frame
    /// gets the full setting and each older one fades a step further.
    static func opacity(ofLayer index: Int, count: Int, newest: Double) -> Double {
        guard count > 0, (0..<count).contains(index) else { return 0 }
        return newest * Double(count - index) / Double(count)
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
