//
//  CameraTypes.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import AVFoundation
import CoreGraphics

nonisolated struct CameraDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

/// One selectable resolution. Several device formats can share a size (differing in pixel format or
/// frame rate), so the engine keeps the best one for each size.
nonisolated struct CameraFormat: Identifiable, Hashable, Sendable {
    /// Index into `AVCaptureDevice.formats`.
    let id: Int
    let photoWidth: Int
    let photoHeight: Int
    let videoWidth: Int
    let videoHeight: Int
    let maxFrameRate: Double

    /// Stable across launches, unlike `id`.
    var key: String { "\(photoWidth)x\(photoHeight)/\(videoWidth)x\(videoHeight)" }

    /// Pixel sizes are inserted as plain digits: a localized number would add a thousands separator
    /// ("1,920 × 1,080"), which isn't how resolutions are written.
    var size: String { "\(photoWidth) × \(photoHeight)" }
    var videoSize: String { "\(videoWidth) × \(videoHeight)" }

    var megapixels: Double { Double(photoWidth * photoHeight) / 1_000_000 }

    var title: String {
        let megapixels = megapixels.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "\(size) (\(megapixels) MP)", comment: "Resolution menu item. Arguments: width × height, then megapixels")
    }

    var shortTitle: String { size }

    var detail: String {
        let fps = maxFrameRate.formatted(.number.precision(.fractionLength(0...1)))
        if photoWidth == videoWidth && photoHeight == videoHeight {
            return String(localized: "Preview at \(fps) fps", comment: "Frame rate of the live preview")
        }
        return String(localized: "Preview \(videoSize) at \(fps) fps", comment: "Arguments: preview width × height, then frame rate")
    }
}

/// Camera controls macOS exposes through AVFoundation. Most USB (UVC) cameras support none of these;
/// built-in and Continuity cameras support some.
nonisolated struct CameraControls: Equatable, Sendable {
    var focusModes: [AVCaptureDevice.FocusMode] = []
    var exposureModes: [AVCaptureDevice.ExposureMode] = []
    var whiteBalanceModes: [AVCaptureDevice.WhiteBalanceMode] = []
    var supportsFocusPoint = false
    var supportsExposurePoint = false
    var supportsTorch = false

    var focusMode: AVCaptureDevice.FocusMode = .locked
    var exposureMode: AVCaptureDevice.ExposureMode = .locked
    var whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode = .locked
    var torchOn = false

    var supportsPointOfInterest: Bool { supportsFocusPoint || supportsExposurePoint }

    var isEmpty: Bool {
        focusModes.count < 2 && exposureModes.count < 2 && whiteBalanceModes.count < 2
            && !supportsPointOfInterest && !supportsTorch
    }
}

/// What the UI needs to know about the configured camera.
nonisolated struct CameraSnapshot: Sendable {
    var formats: [CameraFormat]
    var activeFormatID: Int?
    var controls: CameraControls
}

nonisolated enum CameraError: LocalizedError {
    case deviceUnavailable
    case cannotAddInput
    case cannotAddOutput
    case noImage

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable: String(localized: "The camera is no longer available.")
        case .cannotAddInput: String(localized: "The camera couldn't be opened. It may be in use by another app.")
        case .cannotAddOutput: String(localized: "The camera can't take still photos.")
        case .noImage: String(localized: "The camera didn't return an image.")
        }
    }
}

extension AVCaptureDevice.FocusMode {
    nonisolated var displayName: String {
        switch self {
        case .locked: String(localized: "Locked", comment: "Camera focus, exposure or white balance mode")
        case .autoFocus: String(localized: "Auto (Once)", comment: "Camera focus, exposure or white balance mode")
        case .continuousAutoFocus: String(localized: "Continuous", comment: "Camera focus, exposure or white balance mode")
        @unknown default: String(localized: "Unknown", comment: "Camera focus, exposure or white balance mode")
        }
    }
}

extension AVCaptureDevice.ExposureMode {
    nonisolated var displayName: String {
        switch self {
        case .locked: String(localized: "Locked", comment: "Camera focus, exposure or white balance mode")
        case .autoExpose: String(localized: "Auto (Once)", comment: "Camera focus, exposure or white balance mode")
        case .continuousAutoExposure: String(localized: "Continuous", comment: "Camera focus, exposure or white balance mode")
        case .custom: String(localized: "Custom", comment: "Camera focus, exposure or white balance mode")
        @unknown default: String(localized: "Unknown", comment: "Camera focus, exposure or white balance mode")
        }
    }
}

extension AVCaptureDevice.WhiteBalanceMode {
    nonisolated var displayName: String {
        switch self {
        case .locked: String(localized: "Locked", comment: "Camera focus, exposure or white balance mode")
        case .autoWhiteBalance: String(localized: "Auto (Once)", comment: "Camera focus, exposure or white balance mode")
        case .continuousAutoWhiteBalance: String(localized: "Continuous", comment: "Camera focus, exposure or white balance mode")
        @unknown default: String(localized: "Unknown", comment: "Camera focus, exposure or white balance mode")
        }
    }
}
