# Changelog

All notable changes to MouseOn are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-09

First public release.

### Added

- **Display name in the menu bar**, updated live as the cursor moves between displays
- **Universal Control detection** — recognises when the cursor has crossed to an iPad
- **Sidecar detection** and mirrored-display flagging
- **Connected Displays** panel showing every display with its technical details
- **Find My Cursor** (⌥⌘F) — animated highlight to locate the cursor, with configurable colour
- **Large Cursor** (⌥⌘L) — temporarily enlarges the cursor, with configurable size and duration
- **Custom aliases** per display, emoji supported
- **Custom menu bar colour** per display
- **Emoji-only mode**, name length limits, and menu bar opacity
- **Auto-hide** for the menu bar item
- **Usage statistics** — time spent on each display, stored locally as JSON
- **Shortcuts integration** — five actions: Find My Cursor, Show Large Cursor, Get Current
  Display, List Connected Displays, Move Cursor to Display
- **VoiceOver announcements** on display change
- **Launch at login**
- **Battery-aware polling** — reduces polling frequency on battery power
- **Automatic update checks** against GitHub Releases, with downloads verified against the
  release's published SHA-256 before they are opened

[1.0.0]: https://github.com/Omarabiakar18/MouseOn/releases/tag/v1.0.0
