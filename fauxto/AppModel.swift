//
//  AppModel.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import AppKit
import AVFoundation
import ImageIO
import Observation

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
                cameraState = .failed(error?.localizedDescription ?? "The camera stopped unexpectedly.")
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
                await captureOne(askForName: preferences.askForName)
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

            let date = Date.now
            let camera = selectedDevice?.name ?? "Camera"
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
            errorMessage = "The photo couldn't be taken. \(error.localizedDescription)"
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
        if preferences.namingScheme == .template {
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
            let url = FileNaming.uniqueURL(in: folder, baseName: baseName, fileExtension: format.fileExtension)
            let image = pending.image
            let metadata = pending.metadata
            let thumbnail = try await Task.detached {
                let data = try PhotoRenderer.encode(image, metadata: metadata, as: format, quality: quality)
                try data.write(to: url, options: .atomic)
                return Self.thumbnail(from: data)
            }.value
            // Oldest first, so the newest photo sits at the right end of the strip.
            recentPhotos.append(SavedPhoto(url: url, thumbnail: thumbnail))
            if recentPhotos.count > Self.maxRecentPhotos { recentPhotos.removeFirst() }
            return true
        } catch {
            errorMessage = "The photo couldn't be saved to \(saveLocation.displayPath). \(error.localizedDescription)"
            return false
        }
    }

    /// The name a photo gets when the user doesn't type one. With `reserve`, a numbered name's
    /// number is taken so the next call returns the one after it.
    func nextDefaultName(date: Date = .now, camera: String? = nil, reserve: Bool = false) -> String {
        switch preferences.namingScheme {
        case .template:
            return FileNaming.render(
                template: preferences.nameTemplate,
                date: date,
                sequence: preferences.peekSequenceNumber,
                camera: camera ?? selectedDevice?.name ?? "Camera")
        case .numbered:
            let root = preferences.effectiveNameRoot
            let existing = (try? FileManager.default.contentsOfDirectory(atPath: saveLocation.folderURL.path)) ?? []
            let key = root.lowercased()
            let number = max(FileNaming.highestNumber(root: root, in: existing), issuedNumbers[key] ?? 0) + 1
            if reserve { issuedNumbers[key] = number }
            return FileNaming.numberedName(root: root, number: number)
        }
    }

    func discardPending() {
        if let pendingPhoto { releaseNumber(of: pendingPhoto) }
        pendingPhoto = nil
    }

    /// Gives back a numbered name's number when that photo isn't saved under it, so the series has
    /// no gap. Only the most recent number can be given back.
    private func releaseNumber(of pending: PendingPhoto) {
        let root = preferences.effectiveNameRoot
        let key = root.lowercased()
        guard let issued = issuedNumbers[key],
              pending.defaultName == FileNaming.numberedName(root: root, number: issued) else { return }
        issuedNumbers[key] = issued - 1
    }

    nonisolated private static func thumbnail(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 240,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
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
    /// fauxto, says so and drops its thumbnail, which would otherwise keep failing.
    private func stillExists(_ photo: SavedPhoto) -> Bool {
        if FileManager.default.fileExists(atPath: photo.url.path) { return true }
        recentPhotos.removeAll { $0.id == photo.id }
        errorMessage = "“\(photo.url.lastPathComponent)” is no longer in \((photo.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath). It was moved or deleted outside fauxto, so it has been removed from recent photos."
        return false
    }
}
