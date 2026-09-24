//
//  Preferences.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import Foundation
import Observation

/// User preferences, persisted to UserDefaults. Shared by the main window, the menus and Settings.
@Observable
final class Preferences {
    private enum Key {
        static let fileFormat = "fileFormat"
        static let quality = "compressionQuality"
        static let askForName = "askForName"
        static let nameTemplate = "nameTemplate"
        static let namingScheme = "namingScheme"
        static let nameRoot = "nameRoot"
        static let sequence = "nextSequenceNumber"
        static let playShutterSound = "playShutterSound"
        static let intervalSeconds = "timerSeconds" // the old timer's key; its values are valid intervals
        static let mirrored = "mirrored"
        static let rotation = "rotation"
        static let showControls = "showControls"
        static let lastCameraID = "lastCameraID"
        static let formatByCamera = "formatByCamera"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var fileFormat: ImageFileFormat { didSet { defaults.set(fileFormat.rawValue, forKey: Key.fileFormat) } }
    /// 0...1, used for HEIC and JPEG.
    var quality: Double { didSet { defaults.set(quality, forKey: Key.quality) } }
    var askForName: Bool { didSet { defaults.set(askForName, forKey: Key.askForName) } }
    var nameTemplate: String { didSet { defaults.set(nameTemplate, forKey: Key.nameTemplate) } }
    var namingScheme: NamingScheme { didSet { defaults.set(namingScheme.rawValue, forKey: Key.namingScheme) } }
    /// The root for `.numbered` names, as typed. Use `effectiveNameRoot` when building a file name.
    var nameRoot: String { didSet { defaults.set(nameRoot, forKey: Key.nameRoot) } }
    var playShutterSound: Bool { didSet { defaults.set(playShutterSound, forKey: Key.playShutterSound) } }
    /// Seconds between photos in an interval run; 0 takes a single photo.
    var intervalSeconds: Int { didSet { defaults.set(intervalSeconds, forKey: Key.intervalSeconds) } }
    var mirrored: Bool { didSet { defaults.set(mirrored, forKey: Key.mirrored) } }
    var rotation: Rotation { didSet { defaults.set(rotation.rawValue, forKey: Key.rotation) } }
    var showControls: Bool { didSet { defaults.set(showControls, forKey: Key.showControls) } }

    static let intervalChoices = [0, 1, 2, 3, 5, 10, 15, 30, 60]

    static func intervalTitle(_ seconds: Int) -> String {
        switch seconds {
        case 0: "Single Photo"
        case 1: "Every Second"
        default: "Every \(seconds) Seconds"
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.fileFormat: ImageFileFormat.available.contains(.heic) ? ImageFileFormat.heic.rawValue : ImageFileFormat.jpeg.rawValue,
            Key.quality: 0.9,
            Key.askForName: true,
            Key.nameTemplate: FileNaming.defaultTemplate,
            Key.namingScheme: NamingScheme.template.rawValue,
            Key.nameRoot: FileNaming.defaultRoot,
            Key.sequence: 1,
            Key.playShutterSound: true,
            Key.intervalSeconds: 0,
            Key.mirrored: false,
            Key.rotation: 0,
            Key.showControls: false,
        ])
        fileFormat = ImageFileFormat(rawValue: defaults.string(forKey: Key.fileFormat) ?? "") ?? .jpeg
        quality = defaults.double(forKey: Key.quality)
        askForName = defaults.bool(forKey: Key.askForName)
        nameTemplate = defaults.string(forKey: Key.nameTemplate) ?? FileNaming.defaultTemplate
        namingScheme = NamingScheme(rawValue: defaults.string(forKey: Key.namingScheme) ?? "") ?? .template
        nameRoot = defaults.string(forKey: Key.nameRoot) ?? FileNaming.defaultRoot
        playShutterSound = defaults.bool(forKey: Key.playShutterSound)
        intervalSeconds = defaults.integer(forKey: Key.intervalSeconds)
        mirrored = defaults.bool(forKey: Key.mirrored)
        rotation = Rotation(rawValue: defaults.integer(forKey: Key.rotation)) ?? .none
        showControls = defaults.bool(forKey: Key.showControls)
    }

    var effectiveNameRoot: String {
        let root = FileNaming.sanitize(nameRoot)
        return root.isEmpty ? FileNaming.defaultRoot : root
    }

    /// Returns the next `{n}` value and advances the counter.
    func takeSequenceNumber() -> Int {
        let value = max(1, defaults.integer(forKey: Key.sequence))
        defaults.set(value + 1, forKey: Key.sequence)
        return value
    }

    /// The sequence number the next photo would get, without consuming it.
    var peekSequenceNumber: Int { max(1, defaults.integer(forKey: Key.sequence)) }

    var lastCameraID: String? {
        get { defaults.string(forKey: Key.lastCameraID) }
        set { defaults.set(newValue, forKey: Key.lastCameraID) }
    }

    /// The resolution last chosen for each camera, keyed by the camera's unique ID.
    func formatKey(forCamera id: String) -> String? {
        (defaults.dictionary(forKey: Key.formatByCamera) as? [String: String])?[id]
    }

    func setFormatKey(_ key: String, forCamera id: String) {
        var map = (defaults.dictionary(forKey: Key.formatByCamera) as? [String: String]) ?? [:]
        map[id] = key
        defaults.set(map, forKey: Key.formatByCamera)
    }
}
