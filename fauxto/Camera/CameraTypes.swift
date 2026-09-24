//
//  CameraTypes.swift
//  fauxto
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

    var megapixels: Double { Double(photoWidth * photoHeight) / 1_000_000 }

    var title: String {
        "\(photoWidth) × \(photoHeight)  (\(megapixels.formatted(.number.precision(.fractionLength(1)))) MP)"
    }

    var shortTitle: String { "\(photoWidth) × \(photoHeight)" }

    var detail: String {
        let fps = maxFrameRate.formatted(.number.precision(.fractionLength(0...1)))
        if photoWidth == videoWidth && photoHeight == videoHeight {
            return "Preview at \(fps) fps"
        }
        return "Preview \(videoWidth) × \(videoHeight) at \(fps) fps"
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
        case .deviceUnavailable: "The camera is no longer available."
        case .cannotAddInput: "The camera couldn't be opened. It may be in use by another app."
        case .cannotAddOutput: "The camera can't take still photos."
        case .noImage: "The camera didn't return an image."
        }
    }
}

extension AVCaptureDevice.FocusMode {
    nonisolated var displayName: String {
        switch self {
        case .locked: "Locked"
        case .autoFocus: "Auto (Once)"
        case .continuousAutoFocus: "Continuous"
        @unknown default: "Unknown"
        }
    }
}

extension AVCaptureDevice.ExposureMode {
    nonisolated var displayName: String {
        switch self {
        case .locked: "Locked"
        case .autoExpose: "Auto (Once)"
        case .continuousAutoExposure: "Continuous"
        case .custom: "Custom"
        @unknown default: "Unknown"
        }
    }
}

extension AVCaptureDevice.WhiteBalanceMode {
    nonisolated var displayName: String {
        switch self {
        case .locked: "Locked"
        case .autoWhiteBalance: "Auto (Once)"
        case .continuousAutoWhiteBalance: "Continuous"
        @unknown default: "Unknown"
        }
    }
}
