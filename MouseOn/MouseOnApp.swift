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

    /// Update notification manager for badge indicator
    @ObservedObject private var updateNotifications = UpdateNotificationManager.shared

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

    /// Alias for backward compatibility, with optional update badge
    private var truncatedName: String {
        let text = menuBarText
        if updateNotifications.hasUnseenUpdate {
            return text + " \u{00B7}" // Middle dot as subtle badge
        }
        return text
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

    /// VoiceOver label for the menu bar item — built from the badge-free text
    /// so the middle-dot update indicator isn't read out as a stray glyph
    private var menuBarAccessibilityLabel: String {
        var label = "MouseOn: Currently on \(menuBarText)"
        if updateNotifications.hasUnseenUpdate {
            label += ", update available"
        }
        return label
    }

    /// Combined opacity: user setting × auto-hide visibility
    private var menuBarOpacity: Double {
        let baseOpacity = dependencies.settings.opacity
        let visibilityOpacity = dependencies.autoHide.isVisible ? 1.0 : 0.0
        return baseOpacity * visibilityOpacity
    }

    // MARK: - Body

    var body: some Scene {
        // Menu Bar Extra
        MenuBarExtra {
            menuContent
        } label: {
            Text(truncatedName)
                .foregroundColor(currentDisplayColor)
                .opacity(menuBarOpacity)
                .accessibilityLabel(menuBarAccessibilityLabel)
                .accessibilityHint("Click to open MouseOn menu")
                .onAppear {
                    logger.debug("Menu bar item appeared")
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

        // App menu commands (visible when a window is focused)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    checkForUpdatesManually()
                }
            }
        }
    }

    // MARK: - Update Check

    private func checkForUpdatesManually() {
        Task {
            await UpdateChecker.shared.checkForUpdatesInteractively()
        }
    }

    // MARK: - Glass Container

    /// Groups neighboring Liquid Glass elements on macOS 26 (Tahoe) so their
    /// effects render and blend as one unit; passes content through unchanged
    /// on earlier systems.
    @ViewBuilder
    private func glassGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                content()
            }
        } else {
            content()
        }
    }

    // MARK: - Menu Content

    @ViewBuilder
    private var menuContent: some View {
        glassGroup {
            VStack(spacing: 8) {
                menuButton(
                    "Find My Cursor",
                    icon: "cursorarrow.rays",
                    shortcut: "⌥⌘F",
                    tint: .accentColor
                ) {
                    CursorHighlighter.shared.highlight(
                        color: dependencies.settings.getHighlightNSColor()
                    )
                }
                .accessibilityIdentifier("findCursorButton")
                .accessibilityHint("Shortcut: Option Command F")

                menuButton("Settings...", icon: "gearshape", tint: .secondary) {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .accessibilityIdentifier("settingsButton")

                // TODO: replace with the real Whish Pay donation link (WHISH_DONATION_URL_TODO)
                menuButton("Support MouseOn", icon: "heart", tint: .secondary) {
                    if let donateURL = URL(string: "https://whish.money/WHISH_DONATION_URL_TODO") {
                        NSWorkspace.shared.open(donateURL)
                    }
                }
                .accessibilityIdentifier("supportButton")

                menuButton("Quit MouseOn", icon: "power", tint: .secondary) {
                    logger.info("User initiated quit")
                    dependencies.stats.flush()
                    NSApplication.shared.terminate(nil)
                }
                .accessibilityIdentifier("quitButton")
            }
            .padding(16)
            .frame(width: 220)
        }
    }

    // MARK: - Menu Button

    @ViewBuilder
    private func menuButton(
        _ title: String,
        icon: String,
        shortcut: String? = nil,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(tint)
                    .frame(width: 20)

                Text(title)
                    .font(.body)

                Spacer()

                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MenuButtonGlassModifier())
    }
}

// MARK: - Glass Modifier

/// Applies liquid glass on macOS 26+, plain rounded rect on older systems
private struct MenuButtonGlassModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                .onHover { isHovered = $0 }
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
                .onHover { isHovered = $0 }
        }
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
