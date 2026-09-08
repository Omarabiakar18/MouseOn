# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MouseOn is a native macOS menu bar utility (Swift/SwiftUI) that shows which display the mouse pointer is currently on. It targets macOS 13.0+ and has zero external dependencies — pure Apple frameworks only (CoreGraphics, AppKit, Foundation, Combine, CryptoKit, IOKit, Security).

## Build & Development Commands

```bash
# Build (Debug)
xcodebuild build -project MouseOn.xcodeproj -scheme MouseOn -configuration Debug \
  -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Run all tests
xcodebuild test -project MouseOn.xcodeproj -scheme MouseOn -configuration Debug \
  -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Run a single test (by name)
xcodebuild test -project MouseOn.xcodeproj -scheme MouseOn -configuration Debug \
  -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  -only-testing:"MouseOnTests/SettingsStoreTests/defaultOpacity"

# Lint
swiftlint lint

# Create DMG for distribution
./scripts/build-dmg.sh
```

Pipe through `| xcpretty` for cleaner build output (if installed).

## Architecture

**Service-based with DI container.** `AppDependencies` (in `Services/AppDependencies.swift`) is the central container that creates and wires all services. It conforms to `AppDependenciesProtocol` and is injected into SwiftUI views via `@EnvironmentObject`.

**Initialization order matters:** SettingsStore → StatsManager → DisplayTracker → other managers. Services reference each other through the DI container.

### Key Services

| Service | Responsibility |
|---------|---------------|
| `DisplayTracker` | Polls mouse position, resolves current display |
| `SettingsStore` | UserDefaults-backed settings, custom aliases/colors |
| `StatsManager` | Usage stats persisted to JSON file in App Support |
| `CursorHighlighter` | "Find My Cursor" animation overlay |
| `HotkeyManager` | Global keyboard shortcut (⌥⌘F) |
| `PowerStateMonitor` | Battery-aware polling intervals |
| `AutoHideManager` | Menu bar auto-hide timer |

### Threading Model

- All services and views are `@MainActor` isolated
- Background work (file I/O, network) uses `DispatchQueue` with `[weak self]`
- `nonisolated(unsafe)` with queue-based synchronization for specific background operations
- Stats saving is debounced to avoid blocking UI

### State & Reactivity

Services expose `@Published` properties; views bind via Combine. Weak references in closures prevent retain cycles. Timers and event monitors are cleaned up in `deinit`.

## Testing

Uses **Swift Testing** framework (not XCTest). Tests are in `MouseOnTests/MouseOnTests.swift`. Tests use isolated `UserDefaults` suites (unique per test) to avoid cross-contamination.

Test suites are organized with `@Suite` and individual tests use `@Test("description")`. Assertions use `#expect(...)`.

## Code Conventions

- **Constants:** All magic numbers/strings live in `Constants.swift` (nested enums: `Timing`, `Display`, `Defaults`, `UserDefaultsKeys`, etc.)
- **Logging:** `os.log` via `Logger(subsystem: "com.mouseon.app", category: "...")` — one logger per file
- **MARK comments:** Files use `// MARK: -` sections extensively
- **Feature flags:** `FeatureToggles` struct (Codable) in `Models/FeatureToggles.swift`

## SwiftLint Rules

Line length: warn 120 / error 200. Function body: warn 65 / error 100 lines. File length: warn 750 / error 1200. Opt-in rules: `empty_count`, `closure_spacing`, `force_unwrapping`, `implicitly_unwrapped_optional`.

## CI

GitHub Actions runs on every push/PR to main: build (Debug), tests, SwiftLint, and security scan. Release builds are triggered by `v*` tags. CI runs on `macos-14` runners.
