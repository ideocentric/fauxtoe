//
//  CaptureBar.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import SwiftUI

/// The strip under the preview: recent photos, the shutter button and the interval.
struct CaptureBar: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            // The spacer keeps this side as wide as the right one when the strip is empty, so the
            // shutter stays centered.
            HStack(spacing: 0) {
                RecentPhotosStrip(model: model)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            ShutterButton(model: model)

            HStack {
                Spacer()
                IntervalPicker(model: model)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(height: 84)
        .background(.bar)
    }
}

struct ShutterButton: View {
    let model: AppModel

    var body: some View {
        if model.isShootingInterval {
            Button(action: model.stopShooting) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(ShutterButtonStyle(tint: .gray))
            .keyboardShortcut(.space, modifiers: [])
            .help("Stop interval shooting (Space or ⌘.)")
            .accessibilityLabel("Stop Interval Shooting")
        } else {
            let interval = model.preferences.intervalSeconds
            Button(action: model.takePhoto) {
                Image(systemName: interval > 0 ? "timer" : "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(ShutterButtonStyle(tint: .red))
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!model.canCapture)
            .help(interval > 0
                  ? "Start interval shooting: a photo now, then \(Preferences.intervalTitle(interval).lowercased()) (Space or ⌘T)"
                  : "Take a photo (Space or ⌘T)")
            .accessibilityLabel(interval > 0 ? "Start Interval Shooting" : "Take Photo")
        }
    }
}

private struct ShutterButtonStyle: ButtonStyle {
    let tint: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(Circle().fill(tint.opacity(isEnabled ? 1 : 0.4)))
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2).padding(3))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .contentShape(Circle())
    }
}

struct IntervalPicker: View {
    let model: AppModel

    var body: some View {
        @Bindable var preferences = model.preferences
        Picker(selection: $preferences.intervalSeconds) {
            ForEach(Preferences.intervalChoices, id: \.self) { seconds in
                Text(Preferences.intervalTitle(seconds)).tag(seconds)
            }
        } label: {
            Image(systemName: "timer")
        }
        .pickerStyle(.menu)
        .disabled(model.isShootingInterval)
        .help("Take a single photo, or a photo every few seconds for stop motion and time-lapse")
    }
}

/// Recent photos, oldest on the left and newest on the right. Shows only as many thumbnails as fit
/// whole, and pages through the rest with the arrows, so a thumbnail is never cut off at the edge.
/// It follows the newest photo unless the user has paged back.
struct RecentPhotosStrip: View {
    let model: AppModel
    /// Index of the leftmost thumbnail when paged back; nil follows the newest photo.
    @State private var pinnedFirst: Int?
    @State private var availableWidth: CGFloat = 0

    static let thumbnailSize: CGFloat = 60
    private static let spacing: CGFloat = 8

    private var photos: [SavedPhoto] { model.recentPhotos }

    private var capacity: Int {
        max(1, Int((availableWidth + Self.spacing) / (Self.thumbnailSize + Self.spacing)))
    }

    /// The leftmost index of the newest page.
    private var lastPageStart: Int { max(0, photos.count - capacity) }

    private var first: Int { min(pinnedFirst ?? lastPageStart, lastPageStart) }

    var body: some View {
        // Nothing until the first photo; the save folder is shown in the controls panel.
        if !photos.isEmpty {
            HStack(spacing: 4) {
                Button {
                    pinnedFirst = max(0, first - capacity)
                } label: {
                    Label("Older Photos", systemImage: "chevron.left")
                }
                .disabled(first == 0)
                .help("Show older photos")

                HStack(spacing: Self.spacing) {
                    ForEach(photos[first..<min(photos.count, first + capacity)]) { photo in
                        RecentPhotoThumbnail(model: model, photo: photo)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
                .clipped()

                Button {
                    let next = first + capacity
                    pinnedFirst = next >= lastPageStart ? nil : next
                } label: {
                    Label("Newer Photos", systemImage: "chevron.right")
                }
                .disabled(first >= lastPageStart)
                .help("Show newer photos")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .font(.title3)
            .animation(.easeOut(duration: 0.2), value: photos.last?.id)
            .animation(.easeOut(duration: 0.15), value: first)
            // A new photo brings the strip back to the newest end.
            .onChange(of: photos.last?.id) { pinnedFirst = nil }
        }
    }
}

private struct RecentPhotoThumbnail: View {
    let model: AppModel
    let photo: SavedPhoto

    var body: some View {
        Group {
            if let thumbnail = photo.thumbnail {
                // Fit, not fill, so the whole photo shows.
                Image(decorative: thumbnail, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
            }
        }
        .frame(width: RecentPhotosStrip.thumbnailSize, height: RecentPhotosStrip.thumbnailSize)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
        .contentShape(Rectangle())
        .draggable(photo.url)
        // Outside `draggable` and simultaneous with it: the drag gesture claims the mouse-down, so a
        // tap gesture nested inside it never sees the double click.
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.open(photo) })
        .help(photo.url.lastPathComponent)
        .accessibilityElement()
        .accessibilityLabel(photo.url.lastPathComponent)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.open(photo) }
        .contextMenu {
            Button("Open") { model.open(photo) }
            Button("Show in Finder") { model.revealInFinder(photo) }
            Divider()
            Button("Move to Trash", role: .destructive) { model.moveToTrash(photo) }
        }
    }
}
