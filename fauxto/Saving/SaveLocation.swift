//
//  SaveLocation.swift
//  fauxto
//
//  Copyright (C) 2026 Matt Comeione
//  SPDX-License-Identifier: AGPL-3.0-or-later
//

import AppKit
import Observation

/// The folder photos are saved to. Defaults to ~/Pictures/fauxto; a folder chosen by the user is kept
/// across launches with a security-scoped bookmark, since the app is sandboxed.
@Observable
final class SaveLocation {
    private static let bookmarkKey = "saveFolderBookmark"

    private(set) var folderURL: URL
    private(set) var isDefault: Bool

    @ObservationIgnored private var scopedURL: URL?

    /// The real ~/Pictures/fauxto. FileManager's home directory points inside the sandbox container.
    static var defaultFolder: URL {
        let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("fauxto", isDirectory: true)
    }

    init() {
        folderURL = Self.defaultFolder
        isDefault = true
        restoreBookmark()
    }

    var displayPath: String {
        (folderURL.path as NSString).abbreviatingWithTildeInPath
    }

    /// Creates the folder if needed and returns it.
    func prepareFolder() throws -> URL {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Save Folder")
        panel.prompt = String(localized: "Choose", comment: "Button that confirms the chosen save folder")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folderURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            adopt(url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        releaseScope()
        folderURL = Self.defaultFolder
        isDefault = true
    }

    func revealInFinder() {
        if let folder = try? prepareFolder() {
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        }
    }

    private func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale) else {
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
            return
        }
        adopt(url)
        if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
    }

    private func adopt(_ url: URL) {
        releaseScope()
        if url.startAccessingSecurityScopedResource() { scopedURL = url }
        folderURL = url
        isDefault = false
    }

    private func releaseScope() {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }
}
