//
//  MouseOnIntents.swift
//  MouseOn
//
//  App Intents for macOS Shortcuts integration.
//  Exposes MouseOn actions to the Shortcuts app.
//

import AppIntents
import AppKit

// MARK: - Find My Cursor Intent

/// Triggers the Find My Cursor animation
struct FindMyCursorIntent: AppIntent {
    static var title: LocalizedStringResource = "Find My Cursor"
    static var description = IntentDescription("Shows an animated highlight around your cursor")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            CursorHighlighter.shared.highlight(color: .systemOrange)
        }
        return .result()
    }
}

// MARK: - Get Current Display Intent

/// Returns the name of the display where the cursor is located
struct GetCurrentDisplayIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Current Display"
    static var description = IntentDescription("Returns the name of the display where your cursor is")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> {
        let displayName = await MainActor.run {
            // Get mouse location
            let mouseLocation = NSEvent.mouseLocation

            // Find which screen contains the mouse
            for screen in NSScreen.screens {
                if screen.frame.contains(mouseLocation) {
                    return screen.localizedName
                }
            }
            return "Unknown"
        }
        return .result(value: displayName)
    }
}

// MARK: - Show Large Cursor Intent

/// Shows a large cursor overlay for better visibility
struct ShowLargeCursorIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Large Cursor"
    static var description = IntentDescription("Shows a large cursor for easier visibility")

    @Parameter(title: "Duration (seconds)", default: 5)
    var duration: Int

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            LargeCursorManager.shared.showLargeCursor(duration: TimeInterval(duration))
        }
        return .result()
    }
}

// MARK: - Move Cursor to Display Intent

/// Moves the cursor to a specific display
struct MoveCursorToDisplayIntent: AppIntent {
    static var title: LocalizedStringResource = "Move Cursor to Display"
    static var description = IntentDescription("Moves your cursor to the center of a specific display")

    @Parameter(title: "Display Name")
    var displayName: String

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let moved = await MainActor.run {
            // Find the screen with matching name
            for screen in NSScreen.screens {
                if screen.localizedName.lowercased().contains(displayName.lowercased()) {
                    // Move cursor to center of that screen
                    let centerX = screen.frame.midX
                    let centerY = screen.frame.midY
                    CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))
                    return true
                }
            }
            return false
        }

        if !moved {
            throw IntentError.displayNotFound(displayName)
        }

        return .result()
    }
}

// MARK: - List Displays Intent

/// Returns a list of all connected displays
struct ListDisplaysIntent: AppIntent {
    static var title: LocalizedStringResource = "List Connected Displays"
    static var description = IntentDescription("Returns a list of all connected display names")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<[String]> {
        let displays = await MainActor.run {
            NSScreen.screens.map { $0.localizedName }
        }
        return .result(value: displays)
    }
}

// MARK: - Intent Errors

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case displayNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .displayNotFound(let name):
            return "Display '\(name)' not found"
        }
    }
}

// MARK: - App Shortcuts Provider

/// Provides shortcuts to the Shortcuts app
struct MouseOnShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindMyCursorIntent(),
            phrases: [
                "Find my cursor with \(.applicationName)",
                "Where is my cursor in \(.applicationName)",
                "Highlight cursor with \(.applicationName)"
            ],
            shortTitle: "Find Cursor",
            systemImageName: "cursorarrow.rays"
        )

        AppShortcut(
            intent: GetCurrentDisplayIntent(),
            phrases: [
                "What display am I on with \(.applicationName)",
                "Get current display with \(.applicationName)",
                "Which screen is my cursor on in \(.applicationName)"
            ],
            shortTitle: "Current Display",
            systemImageName: "display"
        )

        AppShortcut(
            intent: ShowLargeCursorIntent(),
            phrases: [
                "Show large cursor with \(.applicationName)",
                "Make cursor bigger with \(.applicationName)",
                "Enlarge cursor with \(.applicationName)"
            ],
            shortTitle: "Large Cursor",
            systemImageName: "arrow.up.left.and.arrow.down.right"
        )

        AppShortcut(
            intent: ListDisplaysIntent(),
            phrases: [
                "List my displays with \(.applicationName)",
                "What displays are connected in \(.applicationName)",
                "Show connected screens with \(.applicationName)"
            ],
            shortTitle: "List Displays",
            systemImageName: "display.2"
        )
    }
}
