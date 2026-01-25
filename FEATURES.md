# MouseOn - Feature Roadmap

A macOS menu bar utility that shows which display your mouse pointer is currently on.

---

## Implemented Features

### Core Functionality

- **Display Name in Menu Bar** - Shows the current display name where the mouse is located
- **Universal Control Detection** - Detects when cursor moves to iPad via Universal Control (keyboard/mouse sharing)
- **Custom Display Aliases** - Rename any display with custom names (supports emojis)
- **Emoji Picker** - Quick access to system emoji picker for display names

### Customization

- **Custom Colors** - Set a unique color for each display name in the menu bar
- **Name Length Limit** - Configure maximum characters shown (5-30)
- **Opacity Control** - Adjust menu bar item opacity (30%-100%)

### Utilities

- **Find My Cursor** - Animated highlight to locate your cursor instantly
- **Usage Statistics** - Track time spent on each display and total switches
- **Auto-hide** - Optionally hide the menu bar item after inactivity
- **Launch at Login** - Start MouseOn automatically when you log in

### Display Information

- **Connected Displays View** - See all connected displays with technical details
- **Sidecar Detection** - Identifies iPad displays connected via Sidecar
- **Mirror Detection** - Shows when displays are in mirroring mode

---

## Planned Features (Next Release)

### Productivity

- [x] **Keyboard Shortcut for Find My Cursor** - Global hotkey ⌥⌘F (Option+Command+F) to trigger cursor highlight
- [ ] **Display Switch Notifications** - Optional notification when switching displays
- [ ] **Quick Display Switcher** - Menu to quickly move cursor to a specific display

### Customization

- [x] **Custom Highlight Colors** - Choose color for Find My Cursor animation
- [ ] **Icon Mode** - Show display icon instead of/alongside text
- [ ] **Font Selection** - Custom font for menu bar display name

### Statistics

- [ ] **Weekly Email Reports** - Receive usage statistics via email
- [ ] **Export Stats** - Export usage data as CSV/JSON
- [ ] **Daily/Weekly/Monthly Views** - Time-based statistics breakdown

---

## Future Ideas

### Advanced Features

- [ ] **Display Profiles** - Save and restore display arrangements
- [ ] **Auto-actions** - Trigger actions when switching to specific displays
- [ ] **Focus Mode Integration** - Different settings per macOS Focus mode
- [ ] **Shortcuts App Integration** - Expose actions to Shortcuts.app

### Multi-device

- [ ] **iPhone Widget** - See current display on iPhone
- [ ] **Apple Watch Complication** - Quick glance at current display
- [ ] **iCloud Sync** - Sync settings across Macs

### Accessibility

- [ ] **VoiceOver Support** - Full accessibility for screen readers
- [ ] **Large Cursor Mode** - Temporarily enlarge cursor when lost
- [ ] **Sound Effects** - Audio feedback on display switch

### Integration

- [ ] **Stream Deck Plugin** - Control MouseOn from Elgato Stream Deck
- [ ] **Alfred/Raycast Extension** - Quick actions from launcher apps
- [ ] **AppleScript Support** - Scriptable actions

---

## Technical Improvements

- [ ] **Reduced Memory Footprint** - Optimize for minimal resource usage
- [ ] **Battery Optimization** - Reduce polling when on battery power
- [ ] **M-series Optimization** - Native Apple Silicon performance tuning

---

## Contributing

Have a feature idea? Open an issue or submit a pull request!

---

_Last updated: January 2026_
