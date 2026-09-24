//
//  PhotoRenderer.swift
//  fauxto
//

import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Applies rotation and mirroring to a captured photo and encodes it in the chosen format.
nonisolated enum PhotoRenderer {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// Bakes rotation and mirroring into the pixels (rather than an EXIF orientation flag) so the
    /// file looks the same in every viewer.
    static func orient(_ image: CGImage, rotation: Rotation, mirrored: Bool) -> CGImage {
        guard rotation != .none || mirrored else { return image }
        var ciImage = CIImage(cgImage: image)
        switch rotation {
        case .none: break
        case .clockwise90: ciImage = ciImage.oriented(.right)
        case .upsideDown: ciImage = ciImage.oriented(.down)
        case .clockwise270: ciImage = ciImage.oriented(.left)
        }
        if mirrored { ciImage = ciImage.oriented(.upMirrored) }
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        return context.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace) ?? image
    }

    /// EXIF and TIFF fields recording when and with what the photo was taken. macOS doesn't hand
    /// back the camera's own metadata, so this is written from what the app knows.
    static func metadata(date: Date, camera: String) -> [String: Any] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let stamp = formatter.string(from: date)
        formatter.dateFormat = "xxx"
        let offset = formatter.string(from: date)
        return [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: stamp,
                kCGImagePropertyExifDateTimeDigitized as String: stamp,
                kCGImagePropertyExifOffsetTimeOriginal as String: offset,
            ],
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFDateTime as String: stamp,
                kCGImagePropertyTIFFModel as String: camera,
                kCGImagePropertyTIFFSoftware as String: "fauxto",
            ],
        ]
    }

    static func encode(_ image: CGImage, metadata: [String: Any], as format: ImageFileFormat, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.utType.identifier as CFString, 1, nil) else {
            throw RenderError.unsupportedFormat(format)
        }
        var properties = metadata
        // Pixels are already upright; a leftover orientation tag would rotate them a second time.
        properties[kCGImagePropertyOrientation as String] = 1
        if var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff[kCGImagePropertyTIFFOrientation as String] = 1
            properties[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        properties[kCGImagePropertyPixelWidth as String] = nil
        properties[kCGImagePropertyPixelHeight as String] = nil
        if format.isLossy {
            properties[kCGImageDestinationLossyCompressionQuality as String] = quality
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.encodingFailed(format) }
        return data as Data
    }

    enum RenderError: LocalizedError {
        case unsupportedFormat(ImageFileFormat)
        case encodingFailed(ImageFileFormat)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let format): "This Mac can't write \(format.displayName) files."
            case .encodingFailed(let format): "The photo couldn't be encoded as \(format.displayName)."
            }
        }
    }
}
