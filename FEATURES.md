# Roadmap

What MouseOn does today, and where it's going. Ideas and pull requests are welcome —
open an [issue](https://github.com/Omarabiakar18/MouseOn/issues) if something here matters
to you, or if something you need is missing.

## Shipping today

### Knowing where your cursor is
- Display name in the menu bar, updated live as the cursor moves
- Universal Control detection — knows when the cursor has crossed to your iPad
- Sidecar detection for iPad-as-display setups
- Mirrored display detection
- Connected Displays panel with per-display technical details

### Finding your cursor
- Find My Cursor — animated highlight, on ⌥⌘F
- Large Cursor — temporary cursor enlargement, on ⌥⌘L
- Configurable colour, size, and duration for both

### Customisation
- Custom alias per display, emoji supported
- Custom menu bar colour per display
- Emoji-only mode
- Name length limit and menu bar opacity
- Auto-hide the menu bar item until the mouse moves

### Everything else
- Usage statistics — time spent per display, stored locally
- Shortcuts integration — five actions for your own automations
- VoiceOver announcements on display change
- Launch at login
- Battery-aware polling that backs off on battery power
- Automatic update checks with SHA-256 verified downloads

## Planned

### Productivity
- [ ] Optional notification when the display changes
- [ ] Quick display switcher — jump the cursor to a chosen display from the menu

### Customisation
- [ ] Icon mode — a display icon instead of, or alongside, the name
- [ ] Font selection for the menu bar item

### Statistics
- [ ] Daily / weekly / monthly breakdowns
- [ ] Export stats as CSV or JSON

## Ideas

Not committed to, but interesting:

- Display profiles — save and restore display arrangements
- Auto-actions triggered by switching to a specific display
- Per-Focus-mode settings
- Sound feedback on display switch
- Stream Deck plugin
- Alfred / Raycast extensions
- iCloud settings sync across Macs

## Non-goals

- **Telemetry or analytics.** MouseOn doesn't phone home, and won't.
- **Accounts or subscriptions.** It's free and open source.
