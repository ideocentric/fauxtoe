//
//  FauxtoCommands.swift
//  fauxto
//

import SwiftUI

/// Menu bar commands. Shortcuts follow Photo Booth (⌘T to take a photo) and Preview (⌘L / ⌘R to rotate).
struct FauxtoCommands: Commands {
    let model: AppModel

    private var preferences: Preferences { model.preferences }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(preferences.intervalSeconds > 0 ? "Start Interval Shooting" : "Take Photo") { model.takePhoto() }
                .keyboardShortcut("t")
                .disabled(!model.canCapture)
            Button("Stop Interval Shooting") { model.stopShooting() }
                .keyboardShortcut(".")
                .disabled(!model.isShootingInterval)
            Divider()
            Button("Show Save Folder in Finder") { model.saveLocation.revealInFinder() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Choose Save Folder…") { model.saveLocation.chooseFolder() }
        }

        CommandMenu("Camera") {
            Picker("Camera", selection: Binding(
                get: { model.selectedDeviceID ?? "" },
                set: { model.chooseDevice($0) }
            )) {
                ForEach(Array(model.devices.enumerated()), id: \.element.id) { index, device in
                    if index < 9 {
                        Text(device.name).tag(device.id)
                            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
                    } else {
                        Text(device.name).tag(device.id)
                    }
                }
            }
            .pickerStyle(.inline)

            Menu("Resolution") {
                ResolutionPicker(model: model)
            }
            .disabled(model.formats.isEmpty)

            Divider()

            Button("Rotate Left") { preferences.rotation = preferences.rotation.rotatedLeft }
                .keyboardShortcut("l")
            Button("Rotate Right") { preferences.rotation = preferences.rotation.rotatedRight }
                .keyboardShortcut("r")
            Toggle("Mirror Image", isOn: Bindable(preferences).mirrored)

            Divider()

            Picker("Interval", selection: Bindable(preferences).intervalSeconds) {
                ForEach(Preferences.intervalChoices, id: \.self) { seconds in
                    Text(Preferences.intervalTitle(seconds)).tag(seconds)
                }
            }
            .disabled(model.isShootingInterval)
        }

        CommandGroup(after: .toolbar) {
            Button(preferences.showControls ? "Hide Camera Controls" : "Show Camera Controls") {
                preferences.showControls.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}
