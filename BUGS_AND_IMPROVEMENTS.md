# MouseOn - Code Review Findings

**Reviewed by:** Boss (Clawdbot)  
**Date:** January 26, 2026

---

## 🐛 Bugs Found

### 1. **totalSwitches not persisted** (StatsManager.swift)
**Severity:** Medium  
**Location:** `StatsManager.swift` lines 95-110

The `totalSwitches` count is not saved to disk - only the `data` dictionary is persisted. This means the switch count resets to 0 every time the app restarts.

**Fix:** Add `internalSwitches` to the save/load methods:
```swift
// In saveInternal():
let statsData = StatsData(data: internalData, switches: internalSwitches)
let encodedData = try JSONEncoder().encode(statsData)

// Create a struct to hold both:
struct StatsData: Codable {
    let data: [String: TimeInterval]
    let switches: Int
}
```

---

### 2. **Wrong GitHub URL in AboutView** (AboutView.swift)
**Severity:** Low  
**Location:** `AboutView.swift` line 72

```swift
// Current (wrong):
if let url = URL(string: "https://github.com/mouseon/mouseon") {

// Should be:
if let url = URL(string: "https://github.com/Omarabiakar18/MouseOn") {
```

---

### 3. **Unused feature toggle** (FeatureToggles.swift)
**Severity:** Low  
**Location:** `FeatureToggles.swift` line 13

`showDataBox` is defined but never used anywhere in the codebase. Either implement it or remove it to avoid confusion.

---

### 4. **Auto-hide feature incomplete**
**Severity:** Medium  
**Location:** Multiple files

The `autoHideEnabled` toggle exists in settings and UI, but there's no actual implementation that hides the menu bar item after inactivity. The timer logic is missing.

**Needs:** A timer in `MouseOnApp.swift` or a dedicated service that:
1. Tracks last mouse movement time
2. Hides menu bar item after `autoHideSeconds`
3. Shows it again on mouse movement

---

### 5. **Opacity not applied to menu bar**
**Severity:** Medium  
**Location:** `MouseOnApp.swift`

The opacity setting exists but isn't actually applied to the menu bar text. The `foregroundColor` is set but opacity modifier is missing.

**Current code:**
```swift
Text(truncatedName)
    .foregroundColor(currentDisplayColor)
```

**Should be:**
```swift
Text(truncatedName)
    .foregroundColor(currentDisplayColor)
    .opacity(dependencies.settings.opacity)
```

---

## ⚠️ Potential Issues

### 1. **Thread safety in StatsManager**
The `nonisolated(unsafe)` markers are used correctly with queue synchronization, but it's a complex pattern. Consider simplifying by making the entire class `@MainActor` and using `Task.detached` for file I/O only.

### 2. **Memory in CursorHighlighter**
The singleton pattern with `Timer` and `DispatchWorkItem` is correctly managed, but if `highlight()` is called rapidly, there could be brief visual glitches. Consider debouncing.

### 3. **No error handling for stats file corruption**
If `stats.json` gets corrupted, the app will silently fail to load stats. Consider adding a backup/recovery mechanism.

---

## ✅ Good Practices Observed

1. **Excellent documentation** - All files have clear header comments
2. **Proper @MainActor usage** - Thread safety is well-handled
3. **Good use of os.log** - Consistent logging throughout
4. **Accessibility identifiers** - Good for UI testing
5. **Constants file** - No magic numbers/strings
6. **Dependency injection** - Clean architecture via AppDependencies
7. **Battery-aware polling** - Power efficiency considered
8. **Comprehensive tests** - Good test coverage exists

---

## 📊 Code Quality Score: 8/10

The codebase is well-structured and professionally written. The bugs found are minor and easily fixable. Main areas for improvement are completing the auto-hide feature and fixing the stats persistence.

---

*Review completed January 26, 2026*
