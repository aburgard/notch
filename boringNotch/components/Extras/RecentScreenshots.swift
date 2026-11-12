//
//  RecentScreenshots.swift
//  boringNotch
//
//  Watches the folder macOS saves screenshots to and lists the newest ones.
//  The app is sandboxed, so the folder is picked once by the user (usually
//  Desktop, or wherever Screenshot.app > Options > Save To points).
//

import AppKit
import CoreServices
import Foundation

struct ScreenshotFile: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
    let created: Date
    var isVideo: Bool { ["mov", "mp4"].contains(url.pathExtension.lowercased()) }
}

@MainActor
final class RecentScreenshots: ObservableObject {
    static let shared = RecentScreenshots()

    @Published private(set) var files: [ScreenshotFile] = []
    let folder = FolderAccess(defaultsKey: "notchExtras.screenshotsFolder")

    /// How many to show in the strip.
    let limit = 20

    private var source: DispatchSourceFileSystemObject?
    private var rescanWork: DispatchWorkItem?

    private static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "pdf", "mov", "mp4"]
    private static let namePrefixes = ["Screenshot", "Screen Shot", "Screen Recording", "CleanShot"]

    private init() {
        watch()
    }

    func chooseFolder() {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        if folder.choose(message: "Pick the folder your screenshots are saved to (usually Desktop).", suggested: desktop) {
            watch()
        }
    }

    // MARK: Actions

    func copyImage(_ file: ScreenshotFile) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if !file.isVideo, let image = NSImage(contentsOf: file.url) {
            pb.writeObjects([image, file.url as NSURL])
        } else {
            pb.writeObjects([file.url as NSURL])
        }
    }

    func open(_ file: ScreenshotFile) {
        NSWorkspace.shared.open(file.url)
    }

    func reveal(_ file: ScreenshotFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    // MARK: Watching

    private func watch() {
        source?.cancel()
        source = nil
        guard let dir = folder.url else { files = []; return }

        let fd = Darwin.open(dir.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("RecentScreenshots: cannot open \(dir.path)")
            files = []
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in
            Task { @MainActor in self?.scheduleRescan() }
        }
        src.setCancelHandler { Darwin.close(fd) }
        src.resume()
        source = src
        rescan()
    }

    /// macOS writes a hidden temp file then renames it, so wait a moment before reading.
    private func scheduleRescan() {
        rescanWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.rescan() }
        }
        rescanWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func rescan() {
        guard let dir = folder.url else { files = []; return }
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []

        let found: [ScreenshotFile] = urls.compactMap { url in
            guard Self.extensions.contains(url.pathExtension.lowercased()) else { return nil }
            guard Self.isScreenCapture(url) else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { return nil }
            return ScreenshotFile(url: url, created: values?.creationDate ?? .distantPast)
        }
        let newest = Array(found.sorted { $0.created > $1.created }.prefix(limit))
        if newest != files { files = newest }
    }

    /// Spotlight tags real screenshots with kMDItemIsScreenCapture. The name
    /// check covers folders Spotlight hasn't indexed yet.
    private static func isScreenCapture(_ url: URL) -> Bool {
        if let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL),
           let flag = MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? Bool, flag {
            return true
        }
        let name = url.lastPathComponent
        return namePrefixes.contains { name.hasPrefix($0) }
    }
}
