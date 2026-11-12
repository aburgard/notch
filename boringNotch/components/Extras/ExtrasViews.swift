//
//  ExtrasViews.swift
//  boringNotch
//
//  Clipboard, Screenshots, and Note tabs. Colors and spacing come from the
//  Aaron Design System's personal-dark theme (the notch is always black).
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Design tokens (personal-dark)

enum ADS {
    static let surface = Color(red: 0x1c / 255, green: 0x1c / 255, blue: 0x1e / 255)
    static let surface2 = Color(red: 0x2c / 255, green: 0x2c / 255, blue: 0x2e / 255)
    static let line = Color(red: 0x38 / 255, green: 0x38 / 255, blue: 0x3a / 255)
    static let ink = Color(red: 0xf5 / 255, green: 0xf5 / 255, blue: 0xf7 / 255)
    static let ink2 = Color(red: 0xa1 / 255, green: 0xa1 / 255, blue: 0xa6 / 255)
    static let accent = Color(red: 0x00 / 255, green: 0x71 / 255, blue: 0xe3 / 255)
    static let accentText = Color(red: 0x29 / 255, green: 0x97 / 255, blue: 0xff / 255)
    static let radius: CGFloat = 12
    static let small = Font.system(size: 13)
    static let body = Font.system(size: 13, weight: .regular)   // notch is tight; 13 is the scale's "small" step
}

/// A card-sized message with one button, for "pick a folder first" states.
struct ExtrasSetupPrompt: View {
    let icon: String
    let message: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 25)).foregroundStyle(ADS.ink2)
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(ADS.small).foregroundStyle(ADS.ink2).fixedSize(horizontal: false, vertical: true)
                Button(button, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .background(Capsule().fill(ADS.accent))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Clipboard

struct ClipboardTabView: View {
    @ObservedObject var history = ClipboardHistory.shared
    @State private var justCopied: UUID?

    var body: some View {
        if history.items.isEmpty {
            EmptyStateView(message: "Copy something and it shows up here")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(history.items) { item in
                        ClipboardCard(item: item, copied: justCopied == item.id)
                            .onTapGesture { copy(item) }
                            .contextMenu {
                                Button(item.pinned ? "Unpin" : "Pin") { history.togglePin(item) }
                                Button("Remove") { history.remove(item) }
                                Divider()
                                Button("Clear unpinned") { history.clearUnpinned() }
                            }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func copy(_ item: ClipboardItem) {
        history.copy(item)
        justCopied = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if justCopied == item.id { justCopied = nil }
        }
    }
}

private struct ClipboardCard: View {
    let item: ClipboardItem
    let copied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(item.sourceApp ?? kindLabel).lineLimit(1)
                Spacer(minLength: 0)
                if item.pinned { Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(ADS.accentText) }
            }
            .font(.system(size: 11))
            .foregroundStyle(ADS.ink2)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(copied ? "Copied" : item.copiedAt.formatted(.relative(presentation: .named)))
                .font(.system(size: 11))
                .foregroundStyle(copied ? ADS.accentText : ADS.ink2)
        }
        .padding(8)
        .frame(width: 150, height: 112)
        .background(RoundedRectangle(cornerRadius: ADS.radius).fill(ADS.surface2))
        .overlay(RoundedRectangle(cornerRadius: ADS.radius).stroke(copied ? ADS.accentText : ADS.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: ADS.radius))
        .help("Click to copy")
    }

    @ViewBuilder private var content: some View {
        if item.kind == .image, let data = item.imageData, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Text(item.preview)
                .font(ADS.body)
                .foregroundStyle(item.kind == .link ? ADS.accentText : ADS.ink)
                .lineLimit(4)
        }
    }

    private var icon: String {
        switch item.kind {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .files: return "doc"
        }
    }

    private var kindLabel: String {
        switch item.kind {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .files: return "Files"
        }
    }
}

// MARK: - Screenshots

struct ScreenshotsTabView: View {
    @ObservedObject var shots = RecentScreenshots.shared
    @ObservedObject private var folder = RecentScreenshots.shared.folder

    var body: some View {
        if folder.url == nil {
            ExtrasSetupPrompt(icon: "camera.viewfinder",
                              message: "Pick the folder your screenshots save to. You only do this once.",
                              button: "Choose folder") { shots.chooseFolder() }
        } else if shots.files.isEmpty {
            EmptyStateView(message: "No screenshots in \(folder.url?.lastPathComponent ?? "that folder") yet")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(shots.files) { file in
                        ScreenshotThumb(file: file)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

private struct ScreenshotThumb: View {
    let file: ScreenshotFile
    @State private var image: NSImage?
    @State private var copied = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: ADS.radius).fill(ADS.surface2)
                if let image {
                    Image(nsImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8)).padding(4)
                } else {
                    ProgressView().controlSize(.small)
                }
                if file.isVideo {
                    Image(systemName: "play.circle.fill").font(.system(size: 25)).foregroundStyle(.white.opacity(0.9))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: ADS.radius).stroke(copied ? ADS.accentText : ADS.line, lineWidth: 1))
            .frame(width: 150, height: 92)

            Text(copied ? "Copied" : file.created.formatted(.relative(presentation: .named)))
                .font(.system(size: 11))
                .foregroundStyle(copied ? ADS.accentText : ADS.ink2)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { RecentScreenshots.shared.open(file) }
        .onTapGesture {
            RecentScreenshots.shared.copyImage(file)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
        }
        .onDrag { NSItemProvider(contentsOf: file.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Copy") { RecentScreenshots.shared.copyImage(file) }
            Button("Open") { RecentScreenshots.shared.open(file) }
            Button("Show in Finder") { RecentScreenshots.shared.reveal(file) }
        }
        .help("Click to copy · double-click to open · drag to drop it anywhere")
        .task(id: file.url) {
            image = await ThumbnailService.shared.thumbnail(for: file.url, size: CGSize(width: 300, height: 184))
        }
    }
}

// MARK: - Note

struct QuickNoteTabView: View {
    @ObservedObject var note = QuickNote.shared
    @ObservedObject private var folder = QuickNote.shared.folder
    @FocusState private var focused: Bool

    var body: some View {
        if folder.url == nil {
            ExtrasSetupPrompt(icon: "square.and.pencil",
                              message: "Pick the Obsidian folder for quick notes, like your vault's Inbox.",
                              button: "Choose folder") { note.chooseFolder() }
        } else {
            HStack(alignment: .top, spacing: 8) {
                TextEditor(text: $note.draft)
                    .font(ADS.body)
                    .foregroundStyle(ADS.ink)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: ADS.radius).fill(ADS.surface2))
                    .overlay(RoundedRectangle(cornerRadius: ADS.radius).stroke(focused ? ADS.accentText : ADS.line, lineWidth: 1))
                    .focused($focused)

                VStack(alignment: .leading, spacing: 8) {
                    Button(action: note.save) {
                        Label("Save", systemImage: "tray.and.arrow.down.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(note.canSave ? ADS.accent : ADS.surface2))
                            .foregroundStyle(note.canSave ? .white : ADS.ink2)
                    }
                    .buttonStyle(.plain)
                    .disabled(!note.canSave)
                    .keyboardShortcut(.return, modifiers: .command)

                    Group {
                        if let error = note.error {
                            Text(error).foregroundStyle(.red)
                        } else if let saved = note.lastSaved {
                            Text("Saved \(saved.deletingPathExtension().lastPathComponent)")
                        } else {
                            Text("⌘↩ saves to \(folder.url?.lastPathComponent ?? "")")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ADS.ink2)
                    .lineLimit(3)

                    Spacer(minLength: 0)
                    Button("Change folder") { note.chooseFolder() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(ADS.accentText)
                }
                .frame(width: 150)
            }
            .padding(.horizontal, 8)
            .onAppear { BoringNotchSkyLightWindow.allowsKeyboardInput = true }
            .onDisappear {
                BoringNotchSkyLightWindow.allowsKeyboardInput = false
                focused = false
            }
        }
    }
}
