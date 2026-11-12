//
//  FolderAccess.swift
//  boringNotch
//
//  Remembers a user-picked folder across launches with a security-scoped
//  bookmark. The app is sandboxed, so it can only read the screenshots folder
//  or write to the Obsidian inbox after the user picks it once.
//

import AppKit
import Foundation

@MainActor
final class FolderAccess: ObservableObject {
    @Published private(set) var url: URL?

    private let defaultsKey: String
    private var isAccessing = false

    init(defaultsKey: String) {
        self.defaultsKey = defaultsKey
        restore()
    }

    /// Shows a folder picker. Returns true when a folder was chosen.
    @discardableResult
    func choose(message: String, suggested: URL? = nil) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = message
        panel.prompt = "Choose"
        if let suggested { panel.directoryURL = suggested }

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let picked = panel.url else { return false }

        do {
            let data = try picked.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: defaultsKey)
            startAccessing(picked)
            return true
        } catch {
            NSLog("FolderAccess: could not save bookmark for \(picked.path): \(error)")
            return false
        }
    }

    func forget() {
        stopAccessing()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        url = nil
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        var stale = false
        do {
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            startAccessing(resolved)
            if stale, let fresh = try? resolved.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: defaultsKey)
            }
        } catch {
            NSLog("FolderAccess: bookmark for \(defaultsKey) no longer resolves: \(error)")
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    private func startAccessing(_ newURL: URL) {
        stopAccessing()
        isAccessing = newURL.startAccessingSecurityScopedResource()
        url = newURL
    }

    private func stopAccessing() {
        if isAccessing { url?.stopAccessingSecurityScopedResource() }
        isAccessing = false
    }
}
