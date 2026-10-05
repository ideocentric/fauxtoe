//
//  CameraPreview.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import AVFoundation
import os
import SwiftUI

/// Live camera preview. Rotation and mirroring are applied to the layer here and to the pixels in
/// `PhotoRenderer`, so what is on screen is what gets saved.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    var rotation: Rotation
    var mirrored: Bool
    var configurationID: Int
    /// Called with a point in device coordinates when the preview is clicked. Nil disables clicking.
    var onClick: ((CGPoint) -> Void)?
    /// Onion skin frames to draw over the preview, newest first. Empty when onion skinning is off.
    var skins: [CGImage] = []
    /// Opacity of the newest skin; older ones fade from there.
    var skinOpacity: Double = 0

    func makeNSView(context: Context) -> PreviewView {
        PreviewView(session: session)
    }

    func updateNSView(_ view: PreviewView, context: Context) {
        view.rotation = rotation
        view.mirrored = mirrored
        view.onClick = onClick
        view.setSkins(skins, opacity: skinOpacity)
        view.refreshConnection()
        view.logVideoRect()
    }
}

final class PreviewView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer
    var onClick: ((CGPoint) -> Void)? {
        didSet { if (onClick == nil) != (oldValue == nil) { window?.invalidateCursorRects(for: self) } }
    }
    var rotation: Rotation = .none { didSet { if rotation != oldValue { needsLayout = true } } }
    var mirrored = false { didSet { if mirrored != oldValue { needsLayout = true } } }
    /// Above the preview layer and not children of it: the frames are already rotated and mirrored,
    /// so they must not pick up the preview's transform.
    private var skinLayers: [CALayer] = []

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspect
        layer?.addSublayer(previewLayer)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Camera preview")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Mirroring is ours to control; the default would mirror some cameras automatically.
    func refreshConnection() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let size = bounds.size
        previewLayer.setAffineTransform(.identity)
        previewLayer.bounds = CGRect(origin: .zero, size: rotation.swapsDimensions ? CGSize(width: size.height, height: size.width) : size)
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        // Layer rotation is counterclockwise for positive angles, so negate for a clockwise turn.
        var transform = CGAffineTransform(rotationAngle: -CGFloat(rotation.rawValue) * .pi / 180)
        if mirrored { transform = transform.concatenating(CGAffineTransform(scaleX: -1, y: 1)) }
        previewLayer.setAffineTransform(transform)
        layoutSkins()
        CATransaction.commit()
        refreshConnection()
        logVideoRect()
    }

    /// Shows `skins` (newest first) over the preview, the newest at `opacity` and older ones fainter.
    func setSkins(_ skins: [CGImage], opacity: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        while skinLayers.count < skins.count {
            let skin = CALayer()
            skin.contentsGravity = .resize
            // Oldest lowest, so the newest frame is drawn last; all stay under the focus indicator.
            layer?.insertSublayer(skin, above: previewLayer)
            skinLayers.append(skin)
        }
        for (index, skin) in skinLayers.enumerated() {
            let image = index < skins.count ? skins[index] : nil
            if skin.contents as! CGImage? !== image { skin.contents = image }
            skin.isHidden = image == nil
            skin.opacity = Float(OnionSkin.opacity(ofLayer: index, count: skins.count, newest: opacity))
        }
        layoutSkins()
        CATransaction.commit()
        setAccessibilityLabel(skins.isEmpty
            ? "Camera preview"
            : String(localized: "Camera preview with onion skin", comment: "Accessibility label for the preview while previous frames are shown over it"))
    }

    /// Each skin is fitted to the bounds by its own aspect ratio, the same fit `.resizeAspect` gives the
    /// live video, so a frame of the same shape lands exactly on the preview. Computed from the bounds
    /// rather than read back from the preview layer, which lags a layout pass behind during a resize.
    private func layoutSkins() {
        for skin in skinLayers {
            guard let image = skin.contents as! CGImage?, image.width > 0, image.height > 0 else { continue }
            skin.frame = AVMakeRect(aspectRatio: CGSize(width: image.width, height: image.height), insideRect: bounds)
        }
    }

    private var loggedVideoRect: CGRect?

    /// Where the video is actually drawn, in this view's layer coordinates: `.resizeAspect`
    /// letterboxes it inside the bounds, and the layer may be rotated. Nil until there is video to
    /// draw: before the session connects, the conversion returns `CGRect.null`, whose origin is
    /// infinite.
    var videoRect: CGRect? {
        guard let root = layer else { return nil }
        let rect = previewLayer.convert(
            previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1)),
            to: root)
        guard !rect.isNull, !rect.isInfinite, !rect.isEmpty,
              [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite) else { return nil }
        return rect
    }

    /// Logged only when it changes, so a live resize doesn't flood the log.
    func logVideoRect() {
        guard let rect = videoRect?.integral, rect != loggedVideoRect else { return }
        loggedVideoRect = rect
        Log.capture.info("Preview: bounds \(Int(self.bounds.width))×\(Int(self.bounds.height)), video drawn at \(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))×\(Int(rect.height))")
    }

    override func mouseDown(with event: NSEvent) {
        guard let onClick, let root = layer else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let inPreview = root.convert(point, to: previewLayer)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: inPreview)
        guard (0...1).contains(devicePoint.x), (0...1).contains(devicePoint.y) else { return }
        showFocusIndicator(at: point)
        onClick(devicePoint)
    }

    override func resetCursorRects() {
        if onClick != nil { addCursorRect(bounds, cursor: .crosshair) }
    }

    private func showFocusIndicator(at point: CGPoint) {
        let side: CGFloat = 70
        let indicator = CAShapeLayer()
        indicator.frame = CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
        indicator.path = CGPath(rect: CGRect(x: 0, y: 0, width: side, height: side), transform: nil)
        indicator.fillColor = nil
        indicator.strokeColor = NSColor.systemYellow.cgColor
        indicator.lineWidth = 1.5
        layer?.addSublayer(indicator)

        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1.4
        shrink.toValue = 1.0
        shrink.duration = 0.2
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 0.8
        fade.duration = 0.3
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        indicator.add(shrink, forKey: "shrink")
        indicator.add(fade, forKey: "fade")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { indicator.removeFromSuperlayer() }
    }
}
