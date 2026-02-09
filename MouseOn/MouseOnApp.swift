//
//  MouseOnApp.swift
//  MouseOn
//
//  A macOS menu bar utility that shows which display the mouse pointer is on.
//  Created 18 Apr 2025
//
//  ## Features
//  - Shows current display name in menu bar
//  - Detects Sidecar (iPad as display)
//  - Detects Universal Control (iPad as separate device)
//  - Find My Cursor with animated highlight
//  - Usage statistics tracking
//  - Custom display aliases and colors
//  - Battery-aware polling for power efficiency
//

import SwiftUI
import AppKit
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "App")

// MARK: - Main App

/// The main entry point for the MouseOn application.
///
/// MouseOn is a menu bar utility that displays the name of the screen
/// where your mouse cursor is currently located. It supports:
/// - Multiple displays including Sidecar (iPad as display)
/// - Universal Control detection (iPad as keyboard/mouse target)
/// - Custom aliases and colors for each display
/// - Find My Cursor feature with keyboard shortcut
/// - Usage statistics tracking
@main
struct MouseOnApp: App {

    // MARK: - Dependencies

    /// Central dependency container managing all services
    @StateObject private var dependencies = AppDependencies()

    /// License manager for activation gating
    @ObservedObject private var licenseManager = LicenseManager.shared

    // MARK: - Environment

    @Environment(\.openWindow) private var openWindow

    // MARK: - Initialization

    init() {
        // Hide Dock icon, run as background-only app
        NSApplication.shared.setActivationPolicy(.accessory)

        logger.info("MouseOn app initialized")

        // Note: Stats flushing is handled in the Quit button action and
        // by the StatsManager using queue.sync in flush() to ensure
        // data is saved before the app terminates.
    }

    // MARK: - Computed Properties

    /// Current screen name or emoji, depending on mode
    private var menuBarText: String {
        // Check emoji mode first
        if dependencies.settings.features.emojiModeEnabled {
            let displayKey = currentDisplayKey
            if let emoji = dependencies.settings.emojiForDisplay(displayKey), !emoji.isEmpty {
                return emoji
            }
            // Fall back to default emoji if none set
            return "🖥️"
        }

        // Regular text mode
        let raw = dependencies.tracker.currentName.isEmpty ? "-" : dependencies.tracker.currentName
        let limit = dependencies.settings.maxNameLength
        return raw.count > limit ? String(raw.prefix(limit)) + "…" : raw
    }

    /// Alias for backward compatibility
    private var truncatedName: String {
        return menuBarText
    }

    /// Current display key for lookups
    private var currentDisplayKey: String {
        if dependencies.tracker.isOnUniversalControl {
            return Constants.SpecialKeys.universalControl
        } else if let id = dependencies.tracker.currentDisplayID {
            return String(id)
        }
        return ""
    }

    /// Color for the current display (if set)
    private var currentDisplayColor: Color {
        let displayKey = currentDisplayKey
        guard !displayKey.isEmpty else { return .primary }
        return dependencies.settings.colorForDisplay(displayKey) ?? .primary
    }

    /// Combined opacity: user setting × auto-hide visibility
    private var menuBarOpacity: Double {
        let baseOpacity = dependencies.settings.opacity
        let visibilityOpacity = dependencies.autoHide.isVisible ? 1.0 : 0.0
        return baseOpacity * visibilityOpacity
    }

    // MARK: - Body

    var body: some Scene {
        // License activation window (shown when not licensed)
        Window("Activate MouseOn", id: "license") {
            LicenseView {
                // On successful activation, this closure fires
                // The @ObservedObject licenseManager will update isLicensed
            }
        }
        .windowResizability(.contentSize)

        // Menu Bar Extra
        MenuBarExtra {
            if licenseManager.isLicensed {
                menuContent
            } else {
                unlicensedMenuContent
            }
        } label: {
            Text(truncatedName)
                .foregroundColor(currentDisplayColor)
                .opacity(menuBarOpacity)
                .accessibilityLabel("MouseOn: Currently on \(truncatedName)")
                .accessibilityHint("Click to open MouseOn menu")
                .onAppear {
                    logger.debug("Menu bar item appeared")
                    // Trigger license revalidation check on app appear
                    Task {
                        await licenseManager.revalidate()
                    }
                    // Show license window if not activated
                    if !licenseManager.isLicensed {
                        openWindow(id: "license")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        }
        .menuBarExtraStyle(.window)

        // Settings Window
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(dependencies.settings)
                .environmentObject(dependencies.tracker)
                .environmentObject(dependencies.launchAtLogin)
        }
        .defaultSize(width: 450, height: 480)

        // Stats Window
        Window("Stats", id: "stats") {
            StatsView()
                .environmentObject(dependencies.stats)
                .environmentObject(dependencies.settings)
        }
        .defaultSize(width: 480, height: 300)

        // Debug Window
        Window("Connected Displays", id: "displays-debug") {
            DisplaysDebugView()
                .environmentObject(dependencies.tracker)
        }
        .defaultSize(width: 550, height: 450)

        // About Window
        Window("About MouseOn", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }

    // MARK: - Unlicensed Menu Content

    @ViewBuilder
    private var unlicensedMenuContent: some View {
        VStack(spacing: 4) {
            Text("MouseOn — Not Activated")
                .font(.headline)

            Text("Please activate your license to use MouseOn.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Button("Activate License...") {
                openWindow(id: "license")
                NSApp.activate(ignoringOtherApps: true)
            }
            .accessibilityIdentifier("activateLicenseButton")

            Divider()

            Button("Quit MouseOn") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(16)
    }

    // MARK: - Menu Content

    @ViewBuilder
    private var menuContent: some View {
        VStack(spacing: 4) {
            // Find My Cursor - useful quick action
            Button("Find My Cursor") {
                CursorHighlighter.shared.highlight(
                    color: dependencies.settings.getHighlightNSColor()
                )
            }
            .keyboardShortcut("f", modifiers: [.option, .command])
            .accessibilityIdentifier("findCursorButton")
            .accessibilityLabel("Find My Cursor")
            .accessibilityHint("Shows an animated highlight around your cursor. Shortcut: Option Command F")

            Divider()

            Button("Settings...") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityIdentifier("settingsButton")

            Divider()

            Button("Quit MouseOn") {
                logger.info("User initiated quit")
                dependencies.stats.flush()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .accessibilityIdentifier("quitButton")
        }
        .padding(16)
    }
}

// MARK: - Preview

#if DEBUG
struct MouseOnApp_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("MouseOn Menu Bar Utility")
                .font(.headline)

            Text("A macOS utility that shows which display your mouse pointer is on.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "display.2")
                Image(systemName: "arrow.right")
                Text("Display Name")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "display.2", title: "Multi-Display", description: "Track cursor across all displays")
                FeatureRow(icon: "ipad", title: "Sidecar Support", description: "Works with iPad as display")
                FeatureRow(icon: "cursorarrow.rays", title: "Find Cursor", description: "Press ⌥⌘F to highlight")
                FeatureRow(icon: "chart.bar", title: "Statistics", description: "Track time per display")
            }
        }
        .padding()
        .frame(width: 350, height: 280)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text(title).font(.callout.bold())
                Text(description).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
#endif
