//
//  CaptureEngine.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import AVFoundation
import CoreImage
import os

/// A photo straight off the sensor, before rotation, mirroring and encoding.
nonisolated struct RawPhoto: @unchecked Sendable {
    let image: CGImage
}

/// Owns the AVCaptureSession. Every session and device call runs on `queue`, so the main thread never
/// blocks on camera reconfiguration. Callers use the async methods.
nonisolated final class CaptureEngine: @unchecked Sendable {
    let session = AVCaptureSession()

    private var photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.ideocentric.fauxto.capture")
    private var input: AVCaptureDeviceInput?
    private var inFlight: [Int64: PhotoCaptureDelegate] = [:]

    static let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .external, .deskViewCamera]

    static func discoverDevices() -> [CameraDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
            .devices
            .map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
    }

    static func preferredDeviceID() -> String? {
        AVCaptureDevice.systemPreferredCamera?.uniqueID
    }

    private func onQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result(catching: work)) }
        }
    }

    // MARK: - Session

    var isRunning: Bool { session.isRunning }

    func start() async {
        _ = try? await onQueue { [session] in
            if !session.isRunning {
                Log.capture.notice("Starting session")
                session.startRunning()
                Log.capture.notice("Session started")
            }
        }
    }

    func stop() async {
        _ = try? await onQueue { [session] in
            if session.isRunning {
                Log.capture.notice("Stopping session")
                session.stopRunning()
                Log.capture.notice("Session stopped")
            }
        }
    }

    /// Switches to the camera with `deviceID` and applies the format whose key is `formatKey`, or the
    /// highest-resolution format when there is no saved choice.
    func select(deviceID: String, formatKey: String?) async throws -> CameraSnapshot {
        try await onQueue { [self] in
            guard let device = AVCaptureDevice(uniqueID: deviceID) else { throw CameraError.deviceUnavailable }
            let newInput = try AVCaptureDeviceInput(device: device)

            session.beginConfiguration()
            defer { session.commitConfiguration() }

            if let input { session.removeInput(input) }
            guard session.canAddInput(newInput) else {
                if let input, session.canAddInput(input) { session.addInput(input) }
                throw CameraError.cannotAddInput
            }
            session.addInput(newInput)
            input = newInput

            // A fresh output per camera, so photo dimensions set for the previous camera can't carry over.
            session.removeOutput(photoOutput)
            photoOutput = AVCapturePhotoOutput()
            guard session.canAddOutput(photoOutput) else { throw CameraError.cannotAddOutput }
            session.addOutput(photoOutput)

            let formats = Self.formats(for: device)
            let target = formats.first { $0.key == formatKey } ?? formats.first
            if let target { try applyFormat(target.id, to: device) }
            return snapshot(for: device, formats: formats)
        }.afterCommit(self)
    }

    func setFormat(_ formatID: Int) async throws -> CameraSnapshot {
        try await onQueue { [self] in
            guard let device = input?.device else { throw CameraError.deviceUnavailable }
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            try applyFormat(formatID, to: device)
            return snapshot(for: device, formats: Self.formats(for: device))
        }.afterCommit(self)
    }

    /// Photo dimensions can only be raised once the output is connected with the new format, so this
    /// runs after `commitConfiguration`.
    fileprivate func configurePhotoDimensions() async {
        _ = try? await onQueue { [self] in
            guard let device = input?.device else { return }
            if let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.area < $1.area }) {
                photoOutput.maxPhotoDimensions = largest
            }
        }
    }

    private func applyFormat(_ formatID: Int, to device: AVCaptureDevice) throws {
        guard device.formats.indices.contains(formatID) else { return }
        try device.lockForConfiguration()
        device.activeFormat = device.formats[formatID]
        device.unlockForConfiguration()
    }

    // MARK: - Controls

    func setFocusMode(_ mode: AVCaptureDevice.FocusMode) async throws -> CameraControls {
        try await configureDevice { device in
            if device.isFocusModeSupported(mode) { device.focusMode = mode }
        }
    }

    func setExposureMode(_ mode: AVCaptureDevice.ExposureMode) async throws -> CameraControls {
        try await configureDevice { device in
            if device.isExposureModeSupported(mode) { device.exposureMode = mode }
        }
    }

    func setWhiteBalanceMode(_ mode: AVCaptureDevice.WhiteBalanceMode) async throws -> CameraControls {
        try await configureDevice { device in
            if device.isWhiteBalanceModeSupported(mode) { device.whiteBalanceMode = mode }
        }
    }

    func setTorch(_ on: Bool) async throws -> CameraControls {
        try await configureDevice { device in
            let mode: AVCaptureDevice.TorchMode = on ? .on : .off
            if device.hasTorch, device.isTorchModeSupported(mode) { device.torchMode = mode }
        }
    }

    /// Focuses and exposes on `point`, in device coordinates (0...1, origin top left of the sensor).
    func focusAndExpose(at point: CGPoint) async throws -> CameraControls {
        try await configureDevice { device in
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                if device.isExposureModeSupported(.autoExpose) { device.exposureMode = .autoExpose }
            }
        }
    }

    private func configureDevice(_ change: @escaping (AVCaptureDevice) -> Void) async throws -> CameraControls {
        try await onQueue { [self] in
            guard let device = input?.device else { throw CameraError.deviceUnavailable }
            try device.lockForConfiguration()
            change(device)
            device.unlockForConfiguration()
            return Self.controls(for: device)
        }
    }

    // MARK: - Capture

    func capturePhoto() async throws -> RawPhoto {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                let settings: AVCapturePhotoSettings
                // Ask for uncompressed pixels so the only lossy step, if any, is the final encode.
                if photoOutput.availablePhotoPixelFormatTypes.contains(kCVPixelFormatType_32BGRA) {
                    settings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
                } else {
                    settings = AVCapturePhotoSettings()
                }
                let maxDimensions = photoOutput.maxPhotoDimensions
                let supported = input?.device.activeFormat.supportedMaxPhotoDimensions ?? []
                if maxDimensions.width > 0, supported.contains(where: { $0.width == maxDimensions.width && $0.height == maxDimensions.height }) {
                    settings.maxPhotoDimensions = maxDimensions
                }

                let id = settings.uniqueID
                let delegate = PhotoCaptureDelegate { [weak self] result in
                    self?.queue.async { self?.inFlight[id] = nil }
                    continuation.resume(with: result)
                }
                inFlight[id] = delegate
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    // MARK: - Device description

    private func snapshot(for device: AVCaptureDevice, formats: [CameraFormat]) -> CameraSnapshot {
        let activeIndex = device.formats.firstIndex(of: device.activeFormat)
        let activeKey = activeIndex.flatMap { index in Self.describe(device.formats[index], index: index)?.key }
        return CameraSnapshot(
            formats: formats,
            activeFormatID: formats.first { $0.key == activeKey }?.id,
            controls: Self.controls(for: device)
        )
    }

    /// Distinct resolutions, largest first, keeping the highest frame rate for each size.
    static func formats(for device: AVCaptureDevice) -> [CameraFormat] {
        var best: [String: CameraFormat] = [:]
        for (index, format) in device.formats.enumerated() {
            guard let described = describe(format, index: index) else { continue }
            if let existing = best[described.key], existing.maxFrameRate >= described.maxFrameRate { continue }
            best[described.key] = described
        }
        return best.values.sorted {
            ($0.photoWidth * $0.photoHeight, $0.videoWidth * $0.videoHeight) > ($1.photoWidth * $1.photoHeight, $1.videoWidth * $1.videoHeight)
        }
    }

    private static func describe(_ format: AVCaptureDevice.Format, index: Int) -> CameraFormat? {
        guard format.mediaType == .video else { return nil }
        let video = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        guard video.width > 0, video.height > 0 else { return nil }
        let photo = format.supportedMaxPhotoDimensions.max(by: { $0.area < $1.area }) ?? video
        return CameraFormat(
            id: index,
            photoWidth: Int(max(photo.width, video.width)),
            photoHeight: Int(max(photo.height, video.height)),
            videoWidth: Int(video.width),
            videoHeight: Int(video.height),
            maxFrameRate: format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
        )
    }

    private static func controls(for device: AVCaptureDevice) -> CameraControls {
        var controls = CameraControls()
        controls.focusModes = [.continuousAutoFocus, .autoFocus, .locked].filter(device.isFocusModeSupported)
        controls.exposureModes = [.continuousAutoExposure, .autoExpose, .locked].filter(device.isExposureModeSupported)
        controls.whiteBalanceModes = [.continuousAutoWhiteBalance, .autoWhiteBalance, .locked].filter(device.isWhiteBalanceModeSupported)
        controls.supportsFocusPoint = device.isFocusPointOfInterestSupported
        controls.supportsExposurePoint = device.isExposurePointOfInterestSupported
        controls.supportsTorch = device.hasTorch && device.isTorchModeSupported(.on)
        controls.focusMode = device.focusMode
        controls.exposureMode = device.exposureMode
        controls.whiteBalanceMode = device.whiteBalanceMode
        controls.torchOn = device.torchMode == .on
        return controls
    }
}

private extension CameraSnapshot {
    nonisolated func afterCommit(_ engine: CaptureEngine) async -> CameraSnapshot {
        await engine.configurePhotoDimensions()
        return self
    }
}

nonisolated extension CMVideoDimensions {
    var area: Int { Int(width) * Int(height) }
}

/// Receives one photo from AVCapturePhotoOutput and turns it into a CGImage.
nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private static let context = CIContext(options: [.cacheIntermediates: false])
    private let completion: (Result<RawPhoto, Error>) -> Void
    private var result: Result<RawPhoto, Error>?

    init(completion: @escaping (Result<RawPhoto, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            result = .failure(error)
            return
        }
        let image: CGImage?
        if let buffer = photo.pixelBuffer {
            let ciImage = CIImage(cvPixelBuffer: buffer)
            image = Self.context.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8,
                                               colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        } else {
            image = photo.cgImageRepresentation()
        }
        if let image {
            result = .success(RawPhoto(image: image))
        } else {
            result = .failure(CameraError.noImage)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error, result == nil { result = .failure(error) }
        completion(result ?? .failure(CameraError.noImage))
    }
}
