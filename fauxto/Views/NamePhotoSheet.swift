//
//  NamePhotoSheet.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import SwiftUI

/// Shown after each photo when "Ask for a name" is on. Return saves, Escape discards.
struct NamePhotoSheet: View {
    let model: AppModel
    let pending: PendingPhoto
    @State private var name: String
    @FocusState private var nameFocused: Bool

    init(model: AppModel, pending: PendingPhoto) {
        self.model = model
        self.pending = pending
        _name = State(initialValue: pending.suggestedName)
    }

    private var preferences: Preferences { model.preferences }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(decorative: pending.image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("The photo you just took")

            Text("\("\(pending.image.width) × \(pending.image.height)") · \(preferences.fileFormat.displayName)",
                 comment: "Photo size (width × height), then file format")
                .font(.caption)
                .foregroundStyle(.secondary)

            LabeledContent("Name:") {
                HStack(spacing: 4) {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                        .onSubmit(save)
                        .labelsHidden()
                    Text(".\(preferences.fileFormat.fileExtension)")
                        .foregroundStyle(.secondary)
                }
            }

            Text("Saving to \(model.saveLocation.displayPath)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack {
                Button("Discard", role: .destructive) { model.discardPending() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if name != pending.defaultName {
                    Button("Use Default Name") { name = pending.defaultName }
                        .help(pending.defaultName)
                }
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            nameFocused = true
        }
    }

    private func save() {
        let chosen = name
        Task { await model.save(pending, as: chosen) }
    }
}
