---
title: Notch Extras
type: project
status: building
created: 2026-11-12
updated: 2026-11-12
upstream: https://github.com/TheBoredTeam/boring.notch (commit b7611bb, 2026-10-31)
tags: [macos, notch, swiftui]
---

# Notch Extras

Aaron's private copy of [Boring.Notch](https://github.com/TheBoredTeam/boring.notch) with three added tabs: Clipboard, Screenshots, and Note. Everything from upstream (media controls, shelf with AirDrop, calendar, HUD) is kept.

## Build and run

1. Open `boringNotch.xcodeproj` in Xcode on the MacBook.
2. Signing & Capabilities: pick your Apple ID as the team (a free one works).
3. Press ⌘R.
4. Settings › Calendar: turn on the calendar if you want the next event in the notch (off by default upstream).

## What was added

| Tab | What it does |
|---|---|
| Clipboard | Last 50 copies plus pinned items. Click to copy again; right-click to pin, remove, or clear unpinned. Skips items password managers mark as concealed or transient. Text history is saved in the app's sandbox; images are memory-only. |
| Screenshots | 20 newest screenshots and screen recordings from a folder you pick once. Click to copy, double-click to open, drag out to drop anywhere. Updates live. |
| Note | Type a note, ⌘↩ saves it to a folder you pick once (your Obsidian inbox) as Markdown with YAML frontmatter. Draft is kept if the notch closes. |

Code lives in `boringNotch/components/Extras/`. Small hooks in `ContentView.swift`, `TabSelectionView.swift`, `enums/generic.swift`, `BoringHeader.swift`, `BoringNotchSkyLightWindow.swift`, and `boringNotchApp.swift`.

## Plan (PRD)

- **Problem:** The notch is dead space, and clipboard history, recent screenshots, and media controls are each several clicks away.
- **Success criteria:** Hovering the notch opens tabs for Media, Shelf, Clipboard, Screenshots, and Note. Starts at login. No noticeable idle CPU or battery cost.
- **Scope in:** Upstream media, shelf/AirDrop, calendar. New Clipboard, Screenshots, and Note tabs. Personal-dark styling from the Aaron Design System.
- **Scope out:** Signed or notarized distribution, other computers, Windows, Claude replies inside the notch.
- **Constraints:** macOS 14+, Xcode, free Apple ID signing. App is sandboxed, so folders are picked once and remembered with security-scoped bookmarks.
- **Plan:** (1) Import upstream. (2) Add tabs. (3) First build on the MacBook and fix compile errors. (4) Test each tab. (5) Launch at login.

## Decisions

| Decision | Why | Rejected |
|---|---|---|
| Fork Boring.Notch | Media controls and notch animation are the hardest parts and already work. | From scratch; buying NotchNook or Alcove |
| Private repo, upstream squashed into one import commit | GitHub forks of public repos can't be private; the shallow import keeps the repo small. | Public fork |
| Clipboard polls the change count every 0.5s | macOS has no clipboard-changed notification; this is the standard approach. | — |
| Note tab lets the notch take keyboard focus only while it's open | Upstream never takes focus; this keeps that true everywhere else. | Always-focusable notch |
| Quick note goes to Obsidian | Aaron's choice. | Claude prompt, Apple Notes |
| Calendar uses the macOS Calendar app, personal calendars only | Aaron's choice; work Outlook calendar not needed. | Adding Outlook to Calendar |

## Known limits

- Typing a note works only while the pointer stays over the notch; the draft is saved if it closes.
- The tab bar now shows even with the shelf turned off.
- Not compiled until the first build on the Mac.

## Pulling upstream updates

```
git remote add upstream https://github.com/TheBoredTeam/boring.notch
git fetch upstream
git merge upstream/main --allow-unrelated-histories
```

The first merge needs `--allow-unrelated-histories` because upstream was imported as one squashed commit.

## License

Upstream is GPL-3.0, so this copy is too. Fine for personal use; if it's ever shared, the source has to be shared with it.
