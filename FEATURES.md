# MouseOn - Feature Roadmap

A macOS menu bar utility that shows which display your mouse pointer is currently on.

---

## ✅ Implemented Features

### Core Functionality
- [x] **Display Name in Menu Bar** - Shows the current display name where the mouse is located
- [x] **Universal Control Detection** - Detects when cursor moves to iPad via Universal Control (keyboard/mouse sharing)
- [x] **Custom Display Aliases** - Rename any display with custom names (supports emojis)
- [x] **Emoji Picker** - Quick access to system emoji picker for display names

### Customization
- [x] **Custom Colors** - Set a unique color for each display name in the menu bar
- [x] **Name Length Limit** - Configure maximum characters shown (5-30)
- [x] **Custom Highlight Colors** - Choose color for Find My Cursor animation
- [x] **Keyboard Shortcut for Find My Cursor** - Global hotkey ⌥⌘F (Option+Command+F)
- [ ] **Opacity Control** - ⚠️ *Setting exists but not applied to menu bar text*

### Utilities
- [x] **Find My Cursor** - Animated highlight to locate your cursor instantly
- [x] **Usage Statistics** - Track time spent on each display (⚠️ *switch count resets on restart - bug*)
- [x] **Launch at Login** - Start MouseOn automatically when you log in
- [ ] **Auto-hide** - ⚠️ *Toggle exists but timer logic not implemented*

### Display Information
- [x] **Connected Displays View** - See all connected displays with technical details
- [x] **Sidecar Detection** - Identifies iPad displays connected via Sidecar
- [x] **Mirror Detection** - Shows when displays are in mirroring mode

---

## 🔧 Needs Fixing (Before Release)

| Issue | Severity | Status |
|-------|----------|--------|
| ~~Opacity not applied to menu bar~~ | Medium | ✅ FIXED |
| Auto-hide timer not implemented | Medium | TODO |
| ~~totalSwitches not persisted~~ | Medium | ✅ FIXED |
| ~~Wrong GitHub URL in About~~ | Low | ✅ FIXED |
| Unused showDataBox toggle | Low | Can remove later |

---

## 📋 Planned Features (Next Release)

### Productivity
- [ ] **Display Switch Notifications** - Optional notification when switching displays
- [ ] **Quick Display Switcher** - Menu to quickly move cursor to a specific display

### Customization
- [ ] **Icon Mode** - Show display icon instead of/alongside text
- [ ] **Font Selection** - Custom font for menu bar display name

### Statistics
- [ ] **Weekly Email Reports** - Receive usage statistics via email
- [ ] **Export Stats** - Export usage data as CSV/JSON
- [ ] **Daily/Weekly/Monthly Views** - Time-based statistics breakdown

---

## 🚀 Future Ideas

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

## 🔧 Technical Improvements

- [ ] **Reduced Memory Footprint** - Optimize for minimal resource usage
- [x] **Battery Optimization** - Reduce polling when on battery power ✅
- [x] **M-series Optimization** - Native Apple Silicon (already native Swift) ✅

---

## 📊 Code Quality

- **Lines of Code:** ~3,700 Swift
- **Test Coverage:** Good (unit tests exist)
- **Architecture:** Clean (Services/Models/Views + DI)
- **Quality Score:** 8/10

---

_Last updated: January 26, 2026_
