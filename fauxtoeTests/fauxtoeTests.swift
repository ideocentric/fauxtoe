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

    @Test func numberedFilesAreNewestFirst() {
        let files = ["walk-002.jpg", "walk-010.heic", "walk-001.jpg", "walk-002 2.jpg", "run-011.jpg", "walk-010.jpg"]
        let found = FileNaming.numberedFiles(root: "walk", in: files)
        #expect(found.map(\.name) == ["walk-010.heic", "walk-010.jpg", "walk-002.jpg", "walk-001.jpg"])
        #expect(found.map(\.number) == [10, 10, 2, 1])
    }

    @Test func uniqueURLNeverReusesAnExistingName() {
        let folder = URL(fileURLWithPath: "/photos", isDirectory: true)
        let taken: Set<String> = ["/photos/shot.jpg", "/photos/shot 2.jpg"]
        let url = FileNaming.uniqueURL(in: folder, baseName: "shot", fileExtension: "jpg") { taken.contains($0.path) }
        #expect(url.path == "/photos/shot 3.jpg")
    }
}

struct PreferencesTests {
    private func freshDefaults() -> UserDefaults {
        let name = "fauxtoeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func onionSkinDefaults() {
        let preferences = Preferences(defaults: freshDefaults())
        #expect(!preferences.onionSkinEnabled)
        #expect(preferences.onionSkinOpacity == 0.4)
        #expect(preferences.onionSkinLayers == 1)
        #expect(preferences.effectiveOnionSkinRoot == "frame")
    }

    @Test func onionSkinSettingsPersist() {
        let defaults = freshDefaults()
        let preferences = Preferences(defaults: defaults)
        preferences.onionSkinEnabled = true
        preferences.onionSkinOpacity = 0.6
        preferences.onionSkinLayers = 3
        preferences.onionSkinRoot = " walk/cycle "
        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.onionSkinEnabled)
        #expect(reloaded.onionSkinOpacity == 0.6)
        #expect(reloaded.onionSkinLayers == 3)
        #expect(reloaded.effectiveOnionSkinRoot == "walk-cycle")
    }

    @Test func onionSkinSequencePersists() {
        let defaults = freshDefaults()
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.onionSkinSequence == nil)
        let sequence = OnionSkinSequence(
            root: "walk", geometry: FrameGeometry(cameraID: "cam-a", formatKey: "640x480/640x480", rotation: 90, mirrored: true))
        preferences.onionSkinSequence = sequence
        #expect(Preferences(defaults: defaults).onionSkinSequence == sequence)
    }

    @Test func onionSkinValuesOutOfRangeAreClamped() {
        let defaults = freshDefaults()
        defaults.set(9, forKey: "onionSkinLayers")
        defaults.set(2.0, forKey: "onionSkinOpacity")
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.onionSkinLayers == 4)
        #expect(preferences.onionSkinOpacity == 0.9)
    }
}

struct OnionSkinTests {
    private let size = CGSize(width: 1920, height: 1080)
    private func url(_ n: Int) -> URL { URL(fileURLWithPath: "/photos/walk-\(n).jpg") }

    @Test func framesOfTheSameSizeLoadNewestFirst() {
        let files = (1...6).reversed().map { (url: url($0), size: Optional(size)) }
        #expect(OnionSkin.framesToLoad(files, frameSize: size) == [url(6), url(5), url(4), url(3)])
    }

    @Test func aDifferentSizeStartsANewSequence() {
        let files: [(url: URL, size: CGSize?)] = [(url(3), CGSize(width: 1280, height: 720)), (url(2), size)]
        #expect(OnionSkin.framesToLoad(files, frameSize: size).isEmpty)
    }

    @Test func loadingStopsAtASequenceBreak() {
        let files: [(url: URL, size: CGSize?)] = [(url(5), size), (url(4), size), (url(3), nil), (url(2), size)]
        #expect(OnionSkin.framesToLoad(files, frameSize: size) == [url(5), url(4)])
    }

    @Test func emptyFolderLoadsNothing() {
        #expect(OnionSkin.framesToLoad([], frameSize: size).isEmpty)
    }

    private let setup = FrameGeometry(cameraID: "cam-a", formatKey: "1920x1440/1920x1440", rotation: 0, mirrored: false)

    @Test func resumesOnlyWithTheSameSetup() {
        let sequence = OnionSkinSequence(root: "walk", geometry: setup)
        #expect(OnionSkin.canResume(sequence, root: "walk", geometry: setup))
        #expect(OnionSkin.canResume(sequence, root: "WALK", geometry: setup))

        var mirrored = setup; mirrored.mirrored = true
        var otherCamera = setup; otherCamera.cameraID = "cam-b"
        var rotated = setup; rotated.rotation = 90
        var otherFormat = setup; otherFormat.formatKey = "640x480/640x480"
        for changed in [mirrored, otherCamera, rotated, otherFormat] {
            #expect(!OnionSkin.canResume(sequence, root: "walk", geometry: changed))
        }
    }

    @Test func withoutARecordTheSizeCheckDecides() {
        #expect(OnionSkin.canResume(nil, root: "walk", geometry: setup))
        let other = OnionSkinSequence(root: "run", geometry: setup)
        var changed = setup; changed.cameraID = "cam-b"
        #expect(OnionSkin.canResume(other, root: "walk", geometry: changed))
    }

    @Test func olderLayersFade() {
        #expect(OnionSkin.opacity(ofLayer: 0, count: 1, newest: 0.4) == 0.4)
        let three = (0..<3).map { OnionSkin.opacity(ofLayer: $0, count: 3, newest: 0.6) }
        #expect(zip(three, [0.6, 0.4, 0.2]).allSatisfy { abs($0 - $1) < 1e-9 })
        #expect(OnionSkin.opacity(ofLayer: 3, count: 3, newest: 0.6) == 0)
    }

    @Test func frameSizeFollowsRotation() {
        let format = CameraFormat(id: 0, photoWidth: 1920, photoHeight: 1080, videoWidth: 1920,
                                  videoHeight: 1080, maxFrameRate: 30)
        #expect(OnionSkin.frameSize(of: format, rotation: .none) == size)
        #expect(OnionSkin.frameSize(of: format, rotation: .clockwise90) == CGSize(width: 1080, height: 1920))
    }

    @Test func pixelSizeIsReadFromTheFile() throws {
        let context = CGContext(data: nil, width: 6, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let data = try PhotoRenderer.encode(context.makeImage()!, metadata: [:], as: .jpeg, quality: 0.9)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(OnionSkin.pixelSize(of: file) == CGSize(width: 6, height: 4))
    }

    @MainActor @Test func sequenceNumberingResumesFromTheFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["walk-011.jpg", "walk-012.heic", "image-050.jpg"] {
            try Data().write(to: folder.appendingPathComponent(name))
        }
        let suite = "fauxtoeTests.\(UUID().uuidString)"
        let preferences = Preferences(defaults: UserDefaults(suiteName: suite)!)
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        preferences.namingScheme = .template
        preferences.onionSkinRoot = "walk"
        let model = AppModel(preferences: preferences, saveLocation: SaveLocation(folder: folder))

        preferences.onionSkinEnabled = true
        #expect(model.nextDefaultName(reserve: true) == "walk-013")
        #expect(model.nextDefaultName() == "walk-014")
        preferences.onionSkinEnabled = false
        #expect(model.nextDefaultName().hasPrefix("fauxtoe "))
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

    @Test func onionSkinFrameCountUsesPluralForms() {
        #expect(String(localized: "Show \(1) frames", comment: "Onion skin: how many previous frames are shown") == "Show 1 frame")
        #expect(String(localized: "Show \(3) frames", comment: "Onion skin: how many previous frames are shown") == "Show 3 frames")
        #expect(FileNaming.defaultOnionSkinRoot == "frame")
    }

    @Test func modelTextIsLocalized() {
        #expect(NamingScheme.numbered.displayName == "Name and number")
        #expect(Rotation.clockwise90.displayName == "90° Clockwise")
        #expect(CameraError.noImage.errorDescription == "The camera didn't return an image.")
    }
}
