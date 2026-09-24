//
//  SavingControls.swift
//  fauxtoe
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import SwiftUI

/// Where photos go, with buttons to change it. Used by the controls panel and Settings.
struct SaveFolderControls: View {
    let saveLocation: SaveLocation

    var body: some View {
        LabeledContent("Folder") {
            Text(saveLocation.displayPath)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(saveLocation.folderURL.path)
        }
        HStack {
            Button("Choose…") { saveLocation.chooseFolder() }
            Button("Show in Finder") { saveLocation.revealInFinder() }
            Spacer()
            if !saveLocation.isDefault {
                Button("Use Default") { saveLocation.resetToDefault() }
                    .help("Save to \((SaveLocation.defaultFolder.path as NSString).abbreviatingWithTildeInPath)")
            }
        }
    }
}

/// How photos are named when no name is typed, with a live example. Used by the controls panel and
/// Settings.
struct NamingControls: View {
    let model: AppModel
    var showsTemplateHelp = false

    private var preferences: Preferences { model.preferences }

    var body: some View {
        @Bindable var preferences = preferences

        Picker("Naming", selection: $preferences.namingScheme) {
            ForEach(NamingScheme.allCases) { Text($0.displayName).tag($0) }
        }

        switch preferences.namingScheme {
        case .numbered:
            TextField("Name", text: $preferences.nameRoot, prompt: Text(FileNaming.defaultRoot))
        case .template:
            TextField("Template", text: $preferences.nameTemplate)
            if showsTemplateHelp {
                DisclosureGroup("Template tokens") {
                    Grid(alignment: .leading, verticalSpacing: 4) {
                        ForEach(FileNaming.tokens, id: \.token) { item in
                            GridRow {
                                Text(item.token).monospaced()
                                Text(item.meaning).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .font(.callout)
                }
                Button("Restore Default Template") { preferences.nameTemplate = FileNaming.defaultTemplate }
                    .disabled(preferences.nameTemplate == FileNaming.defaultTemplate)
            }
        }

        LabeledContent("Next file") {
            // The next number depends on the folder's contents, so refresh after each save.
            let _ = model.recentPhotos.count
            Text(model.nextDefaultName() + "." + preferences.fileFormat.fileExtension)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}
