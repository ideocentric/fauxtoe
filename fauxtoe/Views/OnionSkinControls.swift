//
//  OnionSkinControls.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import SwiftUI

/// Onion skin settings for the inspector: on or off, how faint, how many frames, and the sequence name.
struct OnionSkinControls: View {
    let model: AppModel

    private var preferences: Preferences { model.preferences }

    var body: some View {
        @Bindable var preferences = preferences

        Toggle("Onion Skin", isOn: Binding(
            get: { preferences.onionSkinEnabled },
            set: { model.setOnionSkin($0) }
        ))
        .disabled(model.isShootingInterval)

        Slider(value: $preferences.onionSkinOpacity, in: Preferences.onionSkinOpacityRange) {
            Text("Opacity")
        }

        Stepper(value: $preferences.onionSkinLayers, in: Preferences.onionSkinLayerRange) {
            Text("Show \(preferences.onionSkinLayers) frames", comment: "Onion skin: how many previous frames are shown")
        }

        // Another name is another sequence, so it can only change while onion skinning is off.
        TextField("Sequence", text: $preferences.onionSkinRoot, prompt: Text(FileNaming.defaultOnionSkinRoot))
            .disabled(preferences.onionSkinEnabled)

        if preferences.onionSkinEnabled {
            LabeledContent("Next frame") {
                // The next number depends on the folder's contents, so refresh after each save.
                let _ = model.recentPhotos.count
                Text(model.nextDefaultName() + "." + preferences.fileFormat.fileExtension)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }

        if let notice = model.onionSkinNotice {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Text("Shows the last frames faintly over the preview. Photos save as a numbered sequence without asking for a name, and numbering carries on from the folder. Changing the camera, resolution, rotation or mirroring starts a new sequence.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
