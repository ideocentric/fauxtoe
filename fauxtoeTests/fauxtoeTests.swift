//
//  fauxtoeTests.swift
//  fauxtoeTests
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  Created by Matt Comeione on 9/23/26.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import fauxtoe

struct FileNamingTests {
    private let date: Date = {
        var components = DateComponents()
        (components.year, components.month, components.day) = (2026, 9, 23)
        (components.hour, components.minute, components.second) = (14, 5, 32)
        return Calendar.current.date(from: components)!
    }()

    @Test func rendersDefaultTemplate() {
        let name = FileNaming.render(template: FileNaming.defaultTemplate, date: date, sequence: 7, camera: "Anker")
        #expect(name == "fauxtoe 2026-09-23 at 14.05.32")
    }

    @Test func rendersAllTokens() {
        let name = FileNaming.render(template: "{camera}-{n}-{date}", date: date, sequence: 7, camera: "Scope")
        #expect(name == "Scope-0007-2026-09-23")
    }

    @Test func emptyTemplateFallsBackToDefault() {
        let name = FileNaming.render(template: "  ", date: date, sequence: 1, camera: "X")
        #expect(name == "fauxtoe 2026-09-23 at 14.05.32")
    }

    @Test(arguments: [
        ("board/top", "board-top"),
        ("  spaced  ", "spaced"),
        ("..hidden", "hidden"),
        ("a:b", "a-b"),
        ("shot.jpg", "shot"),
        ("shot.PNG", "shot"),
        ("rev2.1", "rev2.1"),
    ])
    func sanitizes(input: String, expected: String) {
        #expect(FileNaming.sanitize(input) == expected)
    }

    @Test(arguments: [
        ("pcb-top-01", "pcb-top-02"),
        ("board 9", "board 10"),
        ("sample099", "sample100"),
        ("board", "board 2"),
        ("0", "1"),
    ])
    func incrementsSeries(input: String, expected: String) {
        #expect(FileNaming.incremented(input) == expected)
    }

    @Test func numberedNamePadsToThreeDigits() {
        #expect(FileNaming.numberedName(root: "imagename", number: 1) == "imagename-001")
        #expect(FileNaming.numberedName(root: "imagename", number: 1000) == "imagename-1000")
    }

    @Test func highestNumberReadsOnlyMatchingFiles() {
        let files = [
            "imagename-001.jpg",
            "ImageName-007.PNG",      // case-insensitive, any image format
            "imagename-012 2.jpg",    // a collision copy, not part of the series
            "imagename-abc.jpg",
            "imagename-099",          // no extension
            "otherroot-500.jpg",
            "imagename-extra-900.jpg",
            ".DS_Store",
        ]
        #expect(FileNaming.highestNumber(root: "imagename", in: files) == 7)
    }

    @Test func highestNumberIsZeroForEmptyFolder() {
        #expect(FileNaming.highestNumber(root: "imagename", in: []) == 0)
    }

    @Test func uniqueURLNeverReusesAnExistingName() {
        let folder = URL(fileURLWithPath: "/photos", isDirectory: true)
        let taken: Set<String> = ["/photos/shot.jpg", "/photos/shot 2.jpg"]
        let url = FileNaming.uniqueURL(in: folder, baseName: "shot", fileExtension: "jpg") { taken.contains($0.path) }
        #expect(url.path == "/photos/shot 3.jpg")
    }
}

struct PhotoRendererTests {
    /// A 4×2 image whose top-left pixel is red and everything else black.
    private func sample() -> CGImage {
        let context = CGContext(data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 1, width: 1, height: 1)) // CG origin is bottom left
        return context.makeImage()!
    }

    /// Returns whether the pixel at (x, y), counted from the top left, is red.
    private func isRed(_ image: CGImage, x: Int, y: Int) -> Bool {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
        let offset = (y * image.width + x) * 4
        return pixels[offset] > 200 && pixels[offset + 1] < 50
    }

    @Test func rotatesClockwise() {
        let rotated = PhotoRenderer.orient(sample(), rotation: .clockwise90, mirrored: false)
        #expect(rotated.width == 2 && rotated.height == 4)
        #expect(isRed(rotated, x: 1, y: 0))
    }

    @Test func rotatesCounterclockwise() {
        let rotated = PhotoRenderer.orient(sample(), rotation: .clockwise270, mirrored: false)
        #expect(isRed(rotated, x: 0, y: 3))
    }

    @Test func mirrors() {
        let mirrored = PhotoRenderer.orient(sample(), rotation: .none, mirrored: true)
        #expect(isRed(mirrored, x: 3, y: 0))
    }

    @Test(arguments: ImageFileFormat.available)
    func encodesReadableFileWithMetadata(format: ImageFileFormat) throws {
        let metadata = PhotoRenderer.metadata(date: .now, camera: "Test Camera")
        let data = try PhotoRenderer.encode(sample(), metadata: metadata, as: format, quality: 0.9)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == format.utType.identifier)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        #expect(properties[kCGImagePropertyPixelWidth as String] as? Int == 4)
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        #expect(tiff?[kCGImagePropertyTIFFModel as String] as? String == "Test Camera")
    }
}

/// Checks strings resolve through the string catalog, including plural variants. English only:
/// other languages fall back to these until they are translated.
struct LocalizationTests {
    @Test func intervalTitlesUsePluralForms() {
        #expect(Preferences.intervalTitle(0) == "Single Photo")
        #expect(Preferences.intervalTitle(1) == "Every Second")
        #expect(Preferences.intervalTitle(5) == "Every 5 Seconds")
    }

    @Test func formatTitlesComeFromTheCatalog() {
        let format = CameraFormat(id: 0, photoWidth: 1920, photoHeight: 1080, videoWidth: 1920,
                                  videoHeight: 1080, maxFrameRate: 30)
        #expect(format.title == "1920 × 1080 (2.1 MP)")
        #expect(format.detail == "Preview at 30 fps")
    }

    @Test func modelTextIsLocalized() {
        #expect(NamingScheme.numbered.displayName == "Name and number")
        #expect(Rotation.clockwise90.displayName == "90° Clockwise")
        #expect(CameraError.noImage.errorDescription == "The camera didn't return an image.")
    }
}
