//
//  QuickNote.swift
//  boringNotch
//
//  Saves a typed note as an Obsidian-ready Markdown file (YAML frontmatter)
//  in a folder the user picks once, such as the vault's Inbox folder.
//  The draft is kept between openings so nothing is lost if the notch closes.
//

import Foundation

@MainActor
final class QuickNote: ObservableObject {
    static let shared = QuickNote()

    @Published var draft: String {
        didSet { UserDefaults.standard.set(draft, forKey: Self.draftKey) }
    }
    @Published private(set) var lastSaved: URL?
    @Published private(set) var error: String?

    let folder = FolderAccess(defaultsKey: "notchExtras.notesFolder")

    private static let draftKey = "notchExtras.noteDraft"

    private init() {
        draft = UserDefaults.standard.string(forKey: Self.draftKey) ?? ""
    }

    var canSave: Bool {
        folder.url != nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func chooseFolder() {
        let obsidian = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Obsidian")
        folder.choose(message: "Pick the Obsidian folder quick notes should go to (for example, your vault's Inbox).", suggested: obsidian)
    }

    func save() {
        error = nil
        guard let dir = folder.url else { error = "Pick a notes folder first."; return }
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        let now = Date()
        let url = uniqueURL(in: dir, base: Self.fileStamp.string(from: now) + " Quick note")
        let title = Self.firstLine(of: body)
        let markdown = """
        ---
        title: "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
        created: \(Self.isoStamp.string(from: now))
        source: notch
        tags: [inbox, quick-note]
        ---

        \(body)

        """
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            lastSaved = url
            draft = ""
        } catch {
            self.error = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func uniqueURL(in dir: URL, base: String) -> URL {
        var candidate = dir.appendingPathComponent(base).appendingPathExtension("md")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension("md")
            n += 1
        }
        return candidate
    }

    private static func firstLine(of text: String) -> String {
        let line = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? "Quick note"
        return line.count > 60 ? String(line.prefix(60)) + "…" : line
    }

    private static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HHmm"
        return f
    }()

    private static let isoStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()
}
