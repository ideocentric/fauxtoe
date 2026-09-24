//
//  ControlsInspector.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import AVFoundation
import SwiftUI

/// Camera and image controls. Only what the current camera supports is shown.
struct ControlsInspector: View {
    let model: AppModel

    private var preferences: Preferences { model.preferences }
    private var controls: CameraControls { model.controls }

    var body: some View {
        Form {
            Section("Camera") {
                Picker("Camera", selection: Binding(
                    get: { model.selectedDeviceID ?? "" },
                    set: { model.chooseDevice($0) }
                )) {
                    ForEach(model.devices) { Text($0.name).tag($0.id) }
                }

                Picker("Resolution", selection: Binding(
                    get: { model.activeFormatID ?? -1 },
                    set: { model.chooseFormat($0) }
                )) {
                    ForEach(model.formats) { Text($0.shortTitle).tag($0.id) }
                }
                .disabled(model.isReconfiguring)

                if let format = model.activeFormat {
                    Text(format.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Image") {
                Picker("Rotation", selection: Bindable(preferences).rotation) {
                    ForEach(Rotation.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Mirror", isOn: Bindable(preferences).mirrored)
            }

            Section("Adjustments") {
                if controls.isEmpty {
                    Text("This camera doesn't offer focus, exposure or white balance controls to macOS apps.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    if controls.focusModes.count > 1 {
                        Picker("Focus", selection: Binding(
                            get: { controls.focusMode },
                            set: { model.setFocusMode($0) }
                        )) {
                            ForEach(controls.focusModes, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    }
                    if controls.exposureModes.count > 1 {
                        Picker("Exposure", selection: Binding(
                            get: { controls.exposureMode },
                            set: { model.setExposureMode($0) }
                        )) {
                            ForEach(controls.exposureModes, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    }
                    if controls.whiteBalanceModes.count > 1 {
                        Picker("White Balance", selection: Binding(
                            get: { controls.whiteBalanceMode },
                            set: { model.setWhiteBalanceMode($0) }
                        )) {
                            ForEach(controls.whiteBalanceModes, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    }
                    if controls.supportsTorch {
                        Toggle("Light", isOn: Binding(
                            get: { controls.torchOn },
                            set: { model.setTorch($0) }
                        ))
                    }
                    if controls.supportsPointOfInterest {
                        Text("Click the preview to focus and expose on that spot.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if controls.exposureModes.contains(.locked) || controls.whiteBalanceModes.contains(.locked) {
                        Text("Lock exposure and white balance to keep a series of shots consistent.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Capture") {
                Picker("Interval", selection: Bindable(preferences).intervalSeconds) {
                    ForEach(Preferences.intervalChoices, id: \.self) { Text(Preferences.intervalTitle($0)).tag($0) }
                }
                .disabled(model.isShootingInterval)
                if preferences.intervalSeconds > 0 {
                    Text("The shutter takes a photo now, then another every \(preferences.intervalSeconds) seconds until you stop it. Photos save without asking for a name.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Saving") {
                SaveFolderControls(saveLocation: model.saveLocation)
                Picker("Format", selection: Bindable(preferences).fileFormat) {
                    ForEach(ImageFileFormat.available) { Text($0.displayName).tag($0) }
                }
                NamingControls(model: model)
                Toggle("Ask for a name after each photo", isOn: Bindable(preferences).askForName)
            }
        }
        .formStyle(.grouped)
    }
}
