//
//  ContentView.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  Created by Matt Comeione on 9/23/26.
//

import AVFoundation
import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var flashOpacity = 0.0

    private var preferences: Preferences { model.preferences }

    var body: some View {
        VStack(spacing: 0) {
            viewfinder
            CaptureBar(model: model)
        }
        .frame(minWidth: 520, minHeight: 420)
        .navigationTitle(model.selectedDevice?.name ?? "fauxtoe")
        .navigationSubtitle(model.activeFormat?.shortTitle ?? "")
        .toolbar { toolbarContent }
        .inspector(isPresented: Bindable(preferences).showControls) {
            ControlsInspector(model: model)
                .inspectorColumnWidth(min: 240, ideal: 270, max: 360)
        }
        .sheet(item: $model.pendingPhoto) { pending in
            NamePhotoSheet(model: model, pending: pending)
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task { await model.start() }
        .onChange(of: model.flashCount) {
            flashOpacity = 1
            withAnimation(.easeOut(duration: 0.35)) { flashOpacity = 0 }
        }
    }

    @ViewBuilder
    private var viewfinder: some View {
        ZStack {
            Color.black
            CameraPreview(
                session: model.engine.session,
                rotation: preferences.rotation,
                mirrored: preferences.mirrored,
                configurationID: model.configurationID,
                onClick: model.controls.supportsPointOfInterest ? { model.focus(at: $0) } : nil)
                .opacity(model.cameraState == .ready ? 1 : 0)

            CameraStatusView(model: model)

            if let shots = model.intervalShotCount {
                IntervalBadge(shots: shots, secondsUntilNext: model.secondsUntilNextShot)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12)
            }

            Color.white
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("Camera", selection: Binding(
                    get: { model.selectedDeviceID ?? "" },
                    set: { model.chooseDevice($0) }
                )) {
                    ForEach(model.devices) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Camera", systemImage: "web.camera")
            }
            .help("Choose a camera")
            .disabled(model.devices.isEmpty)

            Menu {
                ResolutionPicker(model: model)
            } label: {
                Label("Resolution", systemImage: "aspectratio")
            }
            .help("Choose a resolution")
            .disabled(model.formats.isEmpty)

            Button {
                preferences.rotation = preferences.rotation.rotatedRight
            } label: {
                Label("Rotate Right", systemImage: "rotate.right")
            }
            .help("Rotate the image 90° clockwise")

            Toggle(isOn: Bindable(preferences).mirrored) {
                Label("Mirror", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .help("Flip the image horizontally")

            Button {
                preferences.showControls.toggle()
            } label: {
                Label("Camera Controls", systemImage: "slider.horizontal.3")
            }
            .help("Show or hide camera controls")
        }
    }
}

/// Progress of an interval run, kept small and at the top so it doesn't cover the scene.
struct IntervalBadge: View {
    let shots: Int
    let secondsUntilNext: Int?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
            Text("\(shots) photos", comment: "Interval shooting badge: photos taken so far")
            if let secondsUntilNext {
                Text("·")
                Text("next in \(secondsUntilNext)s", comment: "Interval shooting badge: seconds until the next photo")
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: secondsUntilNext)
            }
        }
        .font(.callout.monospacedDigit().weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Interval shooting, \(shots) photos taken"))
    }
}

/// Explains why there is no picture, when there isn't one.
struct CameraStatusView: View {
    let model: AppModel

    var body: some View {
        switch model.cameraState {
        case .ready:
            EmptyView()
        case .starting, .requestingAccess:
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        case .denied:
            ContentUnavailableView {
                Label("Camera Access Is Off", systemImage: "video.slash")
            } description: {
                Text("Allow fauxtoe to use the camera in System Settings › Privacy & Security › Camera, then reopen fauxtoe.")
            } actions: {
                Button("Open Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .foregroundStyle(.white)
        case .noCamera:
            ContentUnavailableView("No Camera Connected", systemImage: "web.camera",
                                   description: Text("Connect a camera and it will appear here."))
                .foregroundStyle(.white)
        case .failed(let message):
            ContentUnavailableView {
                Label("The Camera Isn't Available", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { model.retry() }
            }
            .foregroundStyle(.white)
        }
    }
}

/// The resolution list, shared by the toolbar, the Camera menu and the inspector.
struct ResolutionPicker: View {
    let model: AppModel

    var body: some View {
        Picker("Resolution", selection: Binding(
            get: { model.activeFormatID ?? -1 },
            set: { model.chooseFormat($0) }
        )) {
            ForEach(model.formats) { format in
                Text(format.title).tag(format.id)
            }
        }
        .pickerStyle(.inline)
    }
}
