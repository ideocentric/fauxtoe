//
//  AppModel.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import AppKit
import AVFoundation
import ImageIO
import Observation
import os

/// A photo that has been taken but not yet named and saved.
struct PendingPhoto: Identifiable {
    let id = UUID()
    let image: CGImage
    let metadata: [String: Any]
    /// The name the naming template produces.
    let defaultName: String
    /// What the name field starts with: the next name in the user's series, or the default.
    let suggestedName: String
}

struct SavedPhoto: Identifiable {
    let id = UUID()
    let url: URL
    let thumbnail: CGImage?
}

@Observable
final class AppModel {
    enum CameraState: Equatable {
        case starting
        case requestingAccess
        case denied
        case noCamera
        case ready
        case failed(String)
    }

    let preferences: Preferences
    let saveLocation: SaveLocation
    let engine = CaptureEngine()

    private(set) var cameraState: CameraState = .starting
    private(set) var devices: [CameraDevice] = []
    private(set) var selectedDeviceID: String?
    private(set) var formats: [CameraFormat] = []
    private(set) var activeFormatID: Int?
    private(set) var controls = CameraControls()
    /// Changes whenever the session is reconfigured, so the preview can refresh its connection.
    private(set) var configurationID = 0
    private(set) var isReconfiguring = false
    private(set) var isCapturing = false
    /// Photos taken so far in the current interval run; nil when no run is active.
    private(set) var intervalShotCount: Int?
    /// Whole seconds until the next shot of an interval run.
    private(set) var secondsUntilNextShot: Int?
    private(set) var flashCount = 0
    private(set) var recentPhotos: [SavedPhoto] = []
    /// The last saved frames of the onion skin sequence, newest first, at preview resolution.
    private(set) var onionSkins: [CGImage] = []
    /// The camera setup `onionSkins` were taken with; they are only shown while it still applies.
    private(set) var onionSkinGeometry: FrameGeometry?
    /// Says why onion skinning started a new sequence instead of showing the previous frames.
    private(set) var onionSkinNotice: String?
    var pendingPhoto: PendingPhoto?
    var errorMessage: String?

    /// The last name the user typed, so the next suggestion can continue the series.
    @ObservationIgnored private var lastCustomName: String?
    /// Numbers handed out this session per root, so quick successive shots don't get the same number
    /// before the first file has been written.
    @ObservationIgnored private var issuedNumbers: [String: Int] = [:]
    @ObservationIgnored private var captureTask: Task<Void, Never>?
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private let shutterSound = NSSound(
        contentsOf: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Shutter.aif"),
        byReference: true)

    private static let maxRecentPhotos = 60

    init(preferences: Preferences = Preferences(), saveLocation: SaveLocation = SaveLocation()) {
        self.preferences = preferences
        self.saveLocation = saveLocation
    }

    var selectedDevice: CameraDevice? { devices.first { $0.id == selectedDeviceID } }
    var activeFormat: CameraFormat? { formats.first { $0.id == activeFormatID } }

    var isShootingInterval: Bool { intervalShotCount != nil }

    /// The camera setup a photo taken now would have. Nil until a camera is running.
    var frameGeometry: FrameGeometry? {
        guard let selectedDeviceID, let format = activeFormat else { return nil }
        return FrameGeometry(cameraID: selectedDeviceID, formatKey: format.key,
                             rotation: preferences.rotation.rawValue, mirrored: preferences.mirrored)
    }

    /// The onion skin frames to draw: none once the camera setup has changed, since they would no
    /// longer line up with the preview.
    var visibleOnionSkins: [CGImage] {
        guard preferences.onionSkinEnabled, let onionSkinGeometry, onionSkinGeometry == frameGeometry else { return [] }
        return onionSkins
    }

    var canCapture: Bool {
        cameraState == .ready && !isReconfiguring && !isCapturing && !isShootingInterval && pendingPhoto == nil
    }

    // MARK: - Camera lifecycle

    func start() async {
        // Unit tests run inside the app; don't open the camera or ask for access there.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            cameraState = .requestingAccess
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                cameraState = .denied
                return
            }
        default:
            cameraState = .denied
            return
        }

        if observationTasks.isEmpty { observeSystemEvents() }
        refreshDevices()
        let preferred = [preferences.lastCameraID, CaptureEngine.preferredDeviceID()].compactMap { $0 }
        guard let id = preferred.first(where: { id in devices.contains { $0.id == id } }) ?? devices.first?.id else {
            cameraState = .noCamera
            return
        }
        await selectDevice(id)
    }

    /// Stops the camera for quitting. Device notifications are dropped first so a camera being
    /// plugged in can't restart the session mid-shutdown.
    func stop() async {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        captureTask?.cancel()
        await engine.stop()
    }

    func retry() {
        cameraState = .starting
        Task { await start() }
    }

    func chooseDevice(_ id: String) {
        guard id != selectedDeviceID else { return }
        Task { await selectDevice(id) }
    }

    func chooseFormat(_ formatID: Int) {
        guard formatID != activeFormatID, !isReconfiguring else { return }
        Task {
            isReconfiguring = true
            defer { isReconfiguring = false }
            do {
                apply(try await engine.setFormat(formatID))
                if let format = activeFormat, let id = selectedDeviceID {
                    preferences.setFormatKey(format.key, forCamera: id)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func selectDevice(_ id: String) async {
        guard !isReconfiguring else { return }
        isReconfiguring = true
        defer { isReconfiguring = false }
        do {
            let snapshot = try await engine.select(deviceID: id, formatKey: preferences.formatKey(forCamera: id))
            selectedDeviceID = id
            preferences.lastCameraID = id
            apply(snapshot)
            await engine.start()
            cameraState = .ready
            // Still on from the last launch: pick the sequence up where it was left.
            if preferences.onionSkinEnabled { await resumeOnionSkin() }
        } catch {
            cameraState = .failed(error.localizedDescription)
        }
    }

    private func apply(_ snapshot: CameraSnapshot) {
        formats = snapshot.formats
        activeFormatID = snapshot.activeFormatID
        controls = snapshot.controls
        configurationID += 1
    }

    private func refreshDevices() {
        devices = CaptureEngine.discoverDevices()
    }

    private func observeSystemEvents() {
        let center = NotificationCenter.default
        observationTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: AVCaptureDevice.wasConnectedNotification) {
                guard let self else { return }
                refreshDevices()
                if cameraState == .noCamera { await start() }
            }
        })
        observationTasks.append(Task { [weak self] in
            for await _ in center.notifications(named: AVCaptureDevice.wasDisconnectedNotification) {
                guard let self else { return }
                refreshDevices()
                if let selectedDeviceID, !devices.contains(where: { $0.id == selectedDeviceID }) {
                    self.selectedDeviceID = nil
                    if let fallback = CaptureEngine.preferredDeviceID() ?? devices.first?.id {
                        await selectDevice(fallback)
                    } else {
                        cameraState = .noCamera
                    }
                }
            }
        })
        observationTasks.append(Task { [weak self] in
            for await note in center.notifications(named: AVCaptureSession.runtimeErrorNotification) {
                guard let self else { return }
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
                cameraState = .failed(error?.localizedDescription ?? String(localized: "The camera stopped unexpectedly."))
            }
        })
    }

    // MARK: - Camera controls

    func setFocusMode(_ mode: AVCaptureDevice.FocusMode) {
        updateControls { try await $0.setFocusMode(mode) }
    }

    func setExposureMode(_ mode: AVCaptureDevice.ExposureMode) {
        updateControls { try await $0.setExposureMode(mode) }
    }

    func setWhiteBalanceMode(_ mode: AVCaptureDevice.WhiteBalanceMode) {
        updateControls { try await $0.setWhiteBalanceMode(mode) }
    }

    func setTorch(_ on: Bool) {
        updateControls { try await $0.setTorch(on) }
    }

    /// Focus and expose on a point in device coordinates, from a click on the preview.
    func focus(at devicePoint: CGPoint) {
        guard controls.supportsPointOfInterest else { return }
        updateControls { try await $0.focusAndExpose(at: devicePoint) }
    }

    private func updateControls(_ change: @escaping (CaptureEngine) async throws -> CameraControls) {
        Task {
            do {
                controls = try await change(engine)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Capture

    /// Takes a photo, or with an interval set, starts a run: one photo now and another every
    /// interval until `stopShooting()`.
    func takePhoto() {
        guard canCapture, captureTask == nil else { return }
        captureTask = Task {
            if preferences.intervalSeconds > 0 {
                await runInterval(every: preferences.intervalSeconds)
            } else {
                // A name prompt would break the onion skin sequence, so its photos save straight away.
                await captureOne(askForName: preferences.askForName && !preferences.onionSkinEnabled)
            }
            captureTask = nil
        }
    }

    func stopShooting() {
        captureTask?.cancel()
    }

    /// Shots are scheduled from the start of the run rather than from the end of the previous save,
    /// so timing doesn't drift. A shot that comes due while the previous one is still saving is
    /// skipped rather than taken late. Photos are saved without asking for a name, since a prompt
    /// would stop the run.
    private func runInterval(every seconds: Int) async {
        let clock = ContinuousClock()
        let interval = Duration.seconds(seconds)
        var nextShot = clock.now
        intervalShotCount = 0
        defer {
            intervalShotCount = nil
            secondsUntilNextShot = nil
        }

        while !Task.isCancelled {
            secondsUntilNextShot = nil
            guard await captureOne(askForName: false) else { return }
            intervalShotCount? += 1

            nextShot += interval
            while nextShot <= clock.now { nextShot += interval }
            while !Task.isCancelled, clock.now < nextShot {
                let remaining = clock.now.duration(to: nextShot)
                secondsUntilNextShot = Int((Double(remaining.components.seconds) + Double(remaining.components.attoseconds) / 1e18).rounded(.up))
                try? await Task.sleep(for: min(remaining, .milliseconds(200)))
            }
        }
    }

    /// Takes and saves (or offers to name) one photo. Returns false if it failed.
    @discardableResult
    private func captureOne(askForName: Bool) async -> Bool {
        isCapturing = true
        defer { isCapturing = false }
        if preferences.playShutterSound {
            shutterSound?.stop()
            shutterSound?.play()
        }
        flashCount += 1

        do {
            let raw = try await engine.capturePhoto()
            let rotation = preferences.rotation
            let mirrored = preferences.mirrored
            let image = await Task.detached {
                PhotoRenderer.orient(raw.image, rotation: rotation, mirrored: mirrored)
            }.value
            Log.capture.info("Captured \(raw.image.width)×\(raw.image.height), oriented \(image.width)×\(image.height)")

            let date = Date.now
            let camera = selectedDevice?.name ?? String(localized: "Camera", comment: "Fallback camera name")
            let defaultName = nextDefaultName(date: date, camera: camera, reserve: true)
            // A numbered root is itself the series; a typed name only continues in template mode.
            let suggestedName = preferences.namingScheme == .template
                ? lastCustomName.map(FileNaming.incremented) ?? defaultName
                : defaultName
            let pending = PendingPhoto(
                image: image,
                metadata: PhotoRenderer.metadata(date: date, camera: camera),
                defaultName: defaultName,
                suggestedName: suggestedName)

            if askForName {
                pendingPhoto = pending
                return true
            }
            return await save(pending, as: pending.defaultName)
        } catch {
            errorMessage = String(localized: "The photo couldn't be taken. \(error.localizedDescription)", comment: "The argument is the system's explanation")
            return false
        }
    }

    // MARK: - Saving

    /// Saves the pending photo under `name`. A name the user typed starts a series that the next
    /// suggestion continues; accepting the default name ends it.
    @discardableResult
    func save(_ pending: PendingPhoto, as name: String) async -> Bool {
        if pendingPhoto?.id == pending.id { pendingPhoto = nil }

        var baseName = FileNaming.sanitize(name)
        if baseName.isEmpty { baseName = pending.defaultName }
        if baseName != pending.defaultName { releaseNumber(of: pending) }
        if preferences.namingScheme == .template && !preferences.onionSkinEnabled {
            if baseName == pending.defaultName {
                lastCustomName = nil
                _ = preferences.takeSequenceNumber()
            } else {
                lastCustomName = baseName
            }
        }

        let format = preferences.fileFormat
        let quality = preferences.quality
        do {
            let folder = try saveLocation.prepareFolder()
            let image = pending.image
            let metadata = pending.metadata
            let skinSize = preferences.onionSkinEnabled ? onionSkinPixelSize : nil
            let geometry = frameGeometry
            let (url, thumbnail, skin) = try await Task.detached { () throws -> (URL, CGImage?, CGImage?) in
                let data = try PhotoRenderer.encode(image, metadata: metadata, as: format, quality: quality)
                // Never replaces an existing file, even one created after the name was chosen.
                let url = try NewFile.write(data, in: folder, baseName: baseName, fileExtension: format.fileExtension)
                guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return (url, nil, nil) }
                return (url, OnionSkin.image(from: source, maxPixelSize: Self.thumbnailPixelSize),
                        skinSize.flatMap { OnionSkin.image(from: source, maxPixelSize: $0) })
            }.value
            // Oldest first, so the newest photo sits at the right end of the strip.
            recentPhotos.append(SavedPhoto(url: url, thumbnail: thumbnail))
            if recentPhotos.count > Self.maxRecentPhotos { recentPhotos.removeFirst() }
            if let skin, let geometry, preferences.onionSkinEnabled {
                // Frames from another setup belong to the previous sequence.
                if geometry != onionSkinGeometry { onionSkins = [] }
                onionSkins.insert(skin, at: 0)
                if onionSkins.count > OnionSkin.maxFrames { onionSkins.removeLast() }
                onionSkinGeometry = geometry
                onionSkinNotice = nil
                preferences.onionSkinSequence = OnionSkinSequence(root: preferences.effectiveOnionSkinRoot, geometry: geometry)
            }
            return true
        } catch {
            errorMessage = String(localized: "The photo couldn't be saved to \(saveLocation.displayPath). \(error.localizedDescription)", comment: "Arguments: the folder path, then the system's explanation")
            return false
        }
    }

    /// The name a photo gets when the user doesn't type one. With `reserve`, a numbered name's
    /// number is taken so the next call returns the one after it.
    func nextDefaultName(date: Date = .now, camera: String? = nil, reserve: Bool = false) -> String {
        if preferences.onionSkinEnabled {
            return nextNumberedName(root: preferences.effectiveOnionSkinRoot, reserve: reserve)
        }
        switch preferences.namingScheme {
        case .template:
            return FileNaming.render(
                template: preferences.nameTemplate,
                date: date,
                sequence: preferences.peekSequenceNumber,
                camera: camera ?? selectedDevice?.name ?? String(localized: "Camera", comment: "Fallback camera name"))
        case .numbered:
            return nextNumberedName(root: preferences.effectiveNameRoot, reserve: reserve)
        }
    }

    /// Numbering continues from what is already in the save folder, so it survives relaunches and
    /// switching onion skinning off and on.
    private func nextNumberedName(root: String, reserve: Bool) -> String {
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: saveLocation.folderURL.path)) ?? []
        let key = root.lowercased()
        let number = max(FileNaming.highestNumber(root: root, in: existing), issuedNumbers[key] ?? 0) + 1
        if reserve { issuedNumbers[key] = number }
        return FileNaming.numberedName(root: root, number: number)
    }

    func discardPending() {
        if let pendingPhoto { releaseNumber(of: pendingPhoto) }
        pendingPhoto = nil
    }

    /// Gives back a numbered name's number when that photo isn't saved under it, so the series has
    /// no gap. Only the most recent number can be given back.
    private func releaseNumber(of pending: PendingPhoto) {
        let root = preferences.onionSkinEnabled ? preferences.effectiveOnionSkinRoot : preferences.effectiveNameRoot
        let key = root.lowercased()
        guard let issued = issuedNumbers[key],
              pending.defaultName == FileNaming.numberedName(root: root, number: issued) else { return }
        issuedNumbers[key] = issued - 1
    }

    nonisolated private static let thumbnailPixelSize = 240

    // MARK: - Onion skin

    /// Turns onion skinning on or off. Not during an interval run, which would change naming midway.
    func setOnionSkin(_ on: Bool) {
        guard on != preferences.onionSkinEnabled, !isShootingInterval else { return }
        preferences.onionSkinEnabled = on
        onionSkins = []
        onionSkinGeometry = nil
        onionSkinNotice = nil
        if on { Task { await resumeOnionSkin() } }
    }

    /// Called when the camera, resolution, rotation or mirroring changes. The frames so far no longer
    /// line up with the preview, so they are dropped and the next photo starts a new keyframe
    /// sequence. Numbering carries on.
    func cameraSetupChanged() {
        guard preferences.onionSkinEnabled, let onionSkinGeometry, onionSkinGeometry != frameGeometry else { return }
        onionSkins = []
        self.onionSkinGeometry = nil
        announceNewSequence()
    }

    private func announceNewSequence() {
        let next = nextDefaultName()
        onionSkinNotice = String(
            localized: "The camera, resolution, rotation or mirroring changed, so the earlier frames are hidden and a new sequence starts with \(next).",
            comment: "Onion skin note. The argument is the next file name, whose numbering carries on")
    }

    /// Skins are kept at the preview's resolution: the preview can't show more detail than that.
    private var onionSkinPixelSize: Int? {
        activeFormat.map { max($0.videoWidth, $0.videoHeight) }
    }

    /// Loads the sequence's last frames from the save folder as skins, if they were taken with this
    /// camera setup. If not, this is a new keyframe sequence: no skins, but the numbering continues.
    private func resumeOnionSkin() async {
        guard preferences.onionSkinEnabled, let format = activeFormat, let skinSize = onionSkinPixelSize,
              let geometry = frameGeometry else { return }
        let folder = saveLocation.folderURL
        let root = preferences.effectiveOnionSkinRoot
        let frameSize = OnionSkin.frameSize(of: format, rotation: preferences.rotation)
        let sameSetup = OnionSkin.canResume(preferences.onionSkinSequence, root: root, geometry: geometry)
        let (loaded, foundAny) = await Task.detached {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            let files = FileNaming.numberedFiles(root: root, in: names)
                .prefix(OnionSkin.maxFrames)
                .map { file -> (url: URL, size: CGSize?) in
                    let url = folder.appendingPathComponent(file.name)
                    return (url, OnionSkin.pixelSize(of: url))
                }
            let skins = !sameSetup ? [] : OnionSkin.framesToLoad(Array(files), frameSize: frameSize).compactMap { url in
                CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { OnionSkin.image(from: $0, maxPixelSize: skinSize) }
            }
            return (skins, !files.isEmpty)
        }.value

        // Turned off, a frame saved, or the setup changed while loading: the newer state wins.
        guard preferences.onionSkinEnabled, onionSkins.isEmpty, root == preferences.effectiveOnionSkinRoot,
              geometry == frameGeometry else { return }
        onionSkins = loaded
        onionSkinGeometry = loaded.isEmpty ? nil : geometry
        if foundAny && loaded.isEmpty { announceNewSequence() }
    }

    // MARK: - Recent photos

    func open(_ photo: SavedPhoto) {
        guard stillExists(photo) else { return }
        NSWorkspace.shared.open(photo.url)
    }

    func revealInFinder(_ photo: SavedPhoto) {
        guard stillExists(photo) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([photo.url])
    }

    func moveToTrash(_ photo: SavedPhoto) {
        guard stillExists(photo) else { return }
        Task {
            do {
                _ = try await NSWorkspace.shared.recycle([photo.url])
                recentPhotos.removeAll { $0.id == photo.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Checks a recent photo's file is still where it was saved. If it was moved or deleted outside
    /// fauxtoe, says so and drops its thumbnail, which would otherwise keep failing.
    private func stillExists(_ photo: SavedPhoto) -> Bool {
        if FileManager.default.fileExists(atPath: photo.url.path) { return true }
        recentPhotos.removeAll { $0.id == photo.id }
        let fileName = photo.url.lastPathComponent
        let folder = (photo.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        errorMessage = String(
            localized: "“\(fileName)” is no longer in \(folder). It was moved or deleted outside fauxtoe, so it has been removed from recent photos.",
            comment: "Arguments: the file name, then its folder")
        return false
    }
}
