# Contributing to MouseOn

Thanks for taking a look. Bug reports, feature ideas, and pull requests are all welcome.

## Getting set up

You need Xcode 15 or later and macOS 13.0+. There are no package dependencies to install — MouseOn uses Apple frameworks only.

```bash
git clone https://github.com/Omarabiakar18/MouseOn.git
cd MouseOn
open MouseOn.xcodeproj
```

## Build, test, lint

```bash
# Build
xcodebuild build -project MouseOn.xcodeproj -scheme MouseOn -configuration Debug \
  -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Test
xcodebuild test -project MouseOn.xcodeproj -scheme MouseOn -configuration Debug \
  -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

# Lint
swiftlint lint
```

CI runs all three on every push and pull request, so it's worth running them locally first.

## How the code is organised

```
MouseOn/
├── Constants.swift      All magic numbers and strings live here
├── MouseOnApp.swift     App entry point and menu bar setup
├── Extensions/          Small helpers on Foundation/AppKit types
├── Intents/             Shortcuts.app actions
├── Models/              DisplayInfo, FeatureToggles
├── Services/            The actual behaviour — see below
└── Views/               SwiftUI: Settings, Stats, About, Displays debug
```

Services are wired together by `AppDependencies`, a small DI container injected into
SwiftUI views as an `@EnvironmentObject`. Initialisation order matters:
`SettingsStore` → `StatsManager` → `DisplayTracker` → everything else.

The services worth knowing about:

| Service | Responsibility |
|---------|---------------|
| `DisplayTracker` | Watches the mouse and resolves which display it's on |
| `SettingsStore` | UserDefaults-backed settings, aliases, colours |
| `StatsManager` | Usage stats, persisted as JSON in Application Support |
| `CursorHighlighter` | The Find My Cursor overlay |
| `LargeCursorManager` | Large cursor mode overlay |
| `HotkeyManager` | Global ⌥⌘F and ⌥⌘L handling |
| `UpdateChecker` | Background update checks and verified downloads |
| `PowerStateMonitor` | Battery-aware polling intervals |
| `AutoHideManager` | Menu bar auto-hide timer |

## Conventions

- Everything user-facing is `@MainActor` isolated. Background work uses `DispatchQueue` with `[weak self]`.
- No magic numbers in service or view code — put them in `Constants.swift` under the right nested enum.
- Logging is `os.log`: one `Logger(subsystem: "com.mouseon.app", category: "…")` per file.
- Use `// MARK: -` sections; the existing files show the pattern.
- SwiftLint enforces the limits (120-char lines, 65-line function bodies, 750-line files). Don't add
  `swiftlint:disable` to get around them — restructure, or raise it in the PR.

## Tests

Tests use **Swift Testing** (not XCTest) and live in `MouseOnTests/MouseOnTests.swift`.
Group related tests in a `@Suite`, name each `@Test("what it proves")`, and assert with `#expect`.
Anything touching UserDefaults must use an isolated suite:

```swift
let defaults = UserDefaults(suiteName: "com.mouseon.tests.\(UUID().uuidString)")!
```

Add tests for any logic you can test without a real display attached — version comparison,
checksum parsing, settings, and stats all have good coverage to copy from.

## Pull requests

1. Branch off `main`.
2. Keep the change focused; one concern per PR.
3. Make sure build, tests, and SwiftLint all pass.
4. Describe what changed and how you verified it.

If you're planning something large, open an issue first so we can talk it through before you
spend the time.

## Reporting bugs

Use the [issue templates](https://github.com/Omarabiakar18/MouseOn/issues/new/choose). For display
detection problems especially, the **Connected Displays** panel in Settings dumps the details we
need — please paste it in, along with your display setup (built-in? external? Sidecar? Universal
Control?).
