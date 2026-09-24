//
//  SettingsView.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            Tab("Saving", systemImage: "folder") {
                SavingSettings(model: model)
            }
            Tab("Capture", systemImage: "camera") {
                CaptureSettings(preferences: model.preferences)
            }
        }
        .frame(width: 520)
    }
}

private struct SavingSettings: View {
    let model: AppModel

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            Section {
                SaveFolderControls(saveLocation: model.saveLocation)
            }

            Section {
                Picker("File format", selection: $preferences.fileFormat) {
                    ForEach(ImageFileFormat.available) { Text($0.displayName).tag($0) }
                }
                if preferences.fileFormat.isLossy {
                    LabeledContent("Quality") {
                        HStack {
                            Slider(value: $preferences.quality, in: 0.5...1.0, step: 0.05)
                            Text(preferences.quality.formatted(.percent.precision(.fractionLength(0))))
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                } else {
                    Text("\(preferences.fileFormat.displayName) is lossless, which suits detail shots of boards and components. Files are larger.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NamingControls(model: model, showsTemplateHelp: true)
                Toggle("Ask for a name after each photo", isOn: $preferences.askForName)
            } footer: {
                (preferences.namingScheme == .numbered
                 ? Text("Numbering continues from the highest number already in the folder. Existing files are never overwritten.")
                 : Text("When you type your own name, the next photo suggests the next name in the series, such as board-02 after board-01. Existing files are never overwritten."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct CaptureSettings: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Form {
            Section {
                Picker("Interval", selection: $preferences.intervalSeconds) {
                    ForEach(Preferences.intervalChoices, id: \.self) { Text(Preferences.intervalTitle($0)).tag($0) }
                }
                Toggle("Play shutter sound", isOn: $preferences.playShutterSound)
            } footer: {
                Text("With an interval set, the shutter takes a photo right away, then another at that interval until you stop it (Space or ⌘.). Use it for stop motion and time-lapse. Interval photos save without asking for a name; Name and number naming gives a tidy frame sequence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Rotation", selection: $preferences.rotation) {
                    ForEach(Rotation.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Mirror image", isOn: $preferences.mirrored)
            } footer: {
                Text("Rotation and mirroring apply to both the preview and saved photos. Use them for cameras mounted sideways or upside down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
