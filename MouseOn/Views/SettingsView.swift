//
//  SettingsView.swift
//  MouseOn
//
//  Settings window with tabbed interface for configuring app behavior,
//  appearance, and display aliases.
//

import SwiftUI

// MARK: - Settings View

/// The main settings window with tabbed interface
///
/// Provides configuration for:
/// - **Appearance**: Colors, opacity, name length
/// - **Behavior**: Launch at login, statistics, auto-hide
/// - **Displays**: Per-display aliases and colors
struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var tracker: DisplayTracker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if #available(macOS 26.0, *) {
            TabView {
                Tab("Appearance", systemImage: "paintbrush") {
                    AppearanceTab()
                }
                Tab("Behavior", systemImage: "gearshape") {
                    BehaviorTab()
                }
                Tab("Displays", systemImage: "display.2") {
                    DisplaysTab()
                }
                Tab("More", systemImage: "ellipsis.circle") {
                    MoreTab(openWindow: openWindow)
                }
            }
            .padding()
            .frame(minWidth: 520, minHeight: 380)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TabView {
                AppearanceTab()
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                BehaviorTab()
                    .tabItem { Label("Behavior", systemImage: "gearshape") }
                DisplaysTab()
                    .tabItem { Label("Displays", systemImage: "display.2") }
                MoreTab(openWindow: openWindow)
                    .tabItem { Label("More", systemImage: "ellipsis.circle") }
            }
            .padding()
            .frame(minWidth: 520, minHeight: 340)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Appearance Tab

/// Settings for visual appearance and Find My Cursor feature
struct AppearanceTab: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Display Name") {
                displayedCharactersSection
            }

            Section("Opacity") {
                opacitySection
            }

            Section("Color") {
                colorModeSection
            }

            Section("Find My Cursor") {
                findMyCursorSection
            }

            Section("Large Cursor Mode") {
                largeCursorSection
            }
        }
        .formStyle(.grouped)
        .onDisappear { settings.save() }
    }

    // MARK: - Sections

    private var displayedCharactersSection: some View {
        Stepper(
            value: $settings.maxNameLength,
            in: Constants.Defaults.nameLengthRange
        ) {
            HStack {
                Text("Displayed characters")
                Spacer()
                Text("\(settings.maxNameLength)")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityIdentifier("maxNameLengthStepper")
        .accessibilityLabel("Maximum displayed characters: \(settings.maxNameLength)")
    }

    private var opacitySection: some View {
        LabeledContent("Menu bar opacity") {
            HStack {
                Slider(
                    value: $settings.opacity,
                    in: Constants.Defaults.opacityRange,
                    step: 0.05
                )
                .accessibilityIdentifier("opacitySlider")

                Text("\(Int(settings.opacity * 100))%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var colorModeSection: some View {
        ColorPicker(
            "Menu bar text color",
            selection: Binding(
                get: { Color(hex: settings.singleAccentColor) ?? .accentColor },
                set: { settings.singleAccentColor = $0.toHex() ?? Constants.Defaults.accentColor }
            ),
            supportsOpacity: false
        )
        .accessibilityIdentifier("accentColorPicker")
    }

    @ViewBuilder
    private var findMyCursorSection: some View {
        ColorPicker(
            "Highlight color",
            selection: Binding(
                get: { Color(hex: settings.highlightColor) ?? .orange },
                set: { settings.highlightColor = $0.toHex() ?? Constants.Defaults.highlightColor }
            ),
            supportsOpacity: false
        )
        .accessibilityIdentifier("highlightColorPicker")

        Toggle(
            "Enable keyboard shortcut",
            isOn: $settings.findCursorHotkeyEnabled
        )
        .accessibilityIdentifier("hotkeyEnabledToggle")

        LabeledContent("Shortcut") {
            HStack(spacing: 4) {
                Text("⌥⌘F")
                    .font(.system(.body, design: .rounded).bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .cornerRadius(4)
                Text("(Option + Command + F)")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)

        Text("Animation follows your cursor movement")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var largeCursorSection: some View {
        Toggle(
            "Enable large cursor mode",
            isOn: $settings.features.largeCursorEnabled
        )
        .accessibilityIdentifier("largeCursorEnabledToggle")

        if settings.features.largeCursorEnabled {
            LabeledContent("Display duration") {
                HStack {
                    Slider(
                        value: $settings.largeCursorDuration,
                        in: Constants.Defaults.largeCursorDurationRange,
                        step: 1.0
                    )
                    Text("\(Int(settings.largeCursorDuration))s")
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
            }

            LabeledContent("Cursor size") {
                HStack {
                    Slider(
                        value: $settings.largeCursorSize,
                        in: Constants.Defaults.largeCursorSizeRange,
                        step: 0.5
                    )
                    Text("\(String(format: "%.1fx", settings.largeCursorSize))")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
            }

            LabeledContent("Shortcut") {
                HStack(spacing: 4) {
                    Text("⌥⌘L")
                        .font(.system(.body, design: .rounded).bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .cornerRadius(4)
                    Text("(Option + Command + L)")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
        }

        Text("Shows a larger cursor for easier visibility")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Behavior Tab

/// Settings for app behavior including launch at login and statistics
struct BehaviorTab: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var launchAtLogin: LaunchAtLoginManager

    var body: some View {
        Form {
            // Launch at Login
            Section("Startup") {
                launchAtLoginSection
            }

            // Statistics
            Section("Statistics") {
                statisticsSection
            }

            // Auto-hide
            Section("Auto-hide") {
                autoHideSection
            }
        }
        .formStyle(.grouped)
        .onDisappear { settings.save() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var launchAtLoginSection: some View {
        Toggle(
            "Launch MouseOn at login",
            isOn: $launchAtLogin.isEnabled
        )
        .accessibilityIdentifier("launchAtLoginToggle")

        if launchAtLogin.statusMessage.contains("approval") {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(launchAtLogin.statusMessage)
                    .font(.caption)
                    .foregroundColor(.orange)

                Spacer()

                Button("Open Settings") {
                    launchAtLogin.openSystemSettings()
                }
                .font(.caption)
                .buttonStyle(.link)
            }
        }
    }

    private var statisticsSection: some View {
        Toggle(
            "Collect pointer-time stats",
            isOn: $settings.features.statsEnabled
        )
        .accessibilityIdentifier("statsEnabledToggle")
    }

    @ViewBuilder
    private var autoHideSection: some View {
        Toggle(
            "Hide menu bar item after inactivity",
            isOn: $settings.features.autoHideEnabled
        )
        .accessibilityIdentifier("autoHideEnabledToggle")

        if settings.features.autoHideEnabled {
            Stepper(
                value: $settings.autoHideSeconds,
                in: Constants.Defaults.autoHideRange,
                step: 5
            ) {
                HStack {
                    Text("Hide after")
                    Spacer()
                    Text("\(settings.autoHideSeconds) seconds")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .accessibilityIdentifier("autoHideSecondsStepper")

            Text("The menu bar item will reappear when you move your mouse")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Displays Tab

/// Settings for individual display aliases and colors
struct DisplaysTab: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            // Emoji mode toggle
            Section("Emoji Mode") {
                Toggle(
                    "Show emoji instead of display name",
                    isOn: $settings.features.emojiModeEnabled
                )
                .accessibilityIdentifier("emojiModeToggle")

                if settings.features.emojiModeEnabled {
                    Text(
                        "Set an emoji for each display below. " +
                        "The emoji will replace the display name in the menu bar."
                    )
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Connected displays
            Section("Connected Displays") {
                displaysList
            }

            // Universal Control
            Section("Universal Control") {
                universalControlSection
            }
        }
        .formStyle(.grouped)
        .onDisappear { settings.save() }
    }

    // MARK: - Sections

    /// Snapshot of screens with stable display IDs to avoid iteration issues
    private var screenSnapshots: [(id: CGDirectDisplayID, name: String)] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID else { return nil }
            return (id: id, name: screen.localizedName)
        }
    }

    @ViewBuilder
    private var displaysList: some View {
        let screens = screenSnapshots
        if screens.isEmpty {
            Text("No displays detected")
                .foregroundColor(.secondary)
        } else {
            ForEach(screens, id: \.id) { screen in
                DisplayRow(
                    displayName: screen.name,
                    displayID: String(screen.id)
                )
            }
        }
    }

    private var universalControlSection: some View {
        DisplayRow(
            displayName: "iPad (Universal Control)",
            displayID: Constants.SpecialKeys.universalControl,
            icon: "ipad"
        )
    }
}

// MARK: - More Tab

/// Additional options and information
struct MoreTab: View {
    let openWindow: OpenWindowAction
    @State private var isCheckingForUpdates = false

    var body: some View {
        Form {
            Section("Updates") {
                Button {
                    checkForUpdates()
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Check for Updates...")
                                if isCheckingForUpdates {
                                    Text("Checking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Version \(UpdateChecker.shared.currentVersion)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Spacer()
                        if isCheckingForUpdates {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isCheckingForUpdates)
            }

            Section("Windows") {
                Button {
                    openWindow(id: "stats")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("View Statistics")
                                Text("Time spent on each display")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.bar")
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    openWindow(id: "displays-debug")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connected Displays")
                                Text("Technical display information")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "display.2")
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }

            Section("About") {
                Button {
                    openWindow(id: "about")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("About MouseOn")
                                Text("Version and credits")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "info.circle")
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
    }

    private func checkForUpdates() {
        isCheckingForUpdates = true
        Task {
            await UpdateChecker.shared.checkForUpdatesInteractively()
            isCheckingForUpdates = false
        }
    }
}

// MARK: - Display Row

/// A row for configuring a single display's custom name
struct DisplayRow: View {
    @EnvironmentObject var settings: SettingsStore

    let displayName: String
    let displayID: String
    var icon: String?

    private var nameBinding: Binding<String> {
        Binding(
            get: { settings.aliases[displayID] ?? "" },
            set: { newValue in
                let sanitized = newValue.unicodeScalars
                    .filter { !CharacterSet.controlCharacters.contains($0) }
                    .map(String.init)
                    .joined()
                let trimmed = String(sanitized.prefix(settings.maxNameLength))
                if trimmed.isEmpty {
                    settings.aliases.removeValue(forKey: displayID)
                } else {
                    settings.aliases[displayID] = trimmed
                }
            }
        )
    }

    private var emojiBinding: Binding<String> {
        Binding(
            get: { settings.displayEmojis[displayID] ?? "" },
            set: { newValue in
                // Only keep first character (emoji) or clear
                let emoji = newValue.first.map(String.init) ?? ""
                if emoji.isEmpty {
                    settings.displayEmojis.removeValue(forKey: displayID)
                } else {
                    settings.displayEmojis[displayID] = emoji
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // Display name with optional icon
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                }
                Text(displayName)
                    .lineLimit(1)
            }

            Spacer()

            // Custom name input + emoji
            HStack(spacing: 6) {
                if !settings.features.emojiModeEnabled {
                    TextField("Custom name", text: nameBinding)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.leading)
                        .frame(width: 140)
                        .accessibilityLabel("Custom name for \(displayName)")
                }

                // Emoji picker — always show, but more prominent in emoji mode
                TextField(settings.features.emojiModeEnabled ? "🖥️" : "", text: emojiBinding)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: settings.features.emojiModeEnabled ? 60 : 40)
                    .accessibilityLabel("Emoji for \(displayName)")

                Button {
                    NSApp.orderFrontCharacterPalette(nil)
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Choose emoji")
                .accessibilityLabel("Emoji picker for \(displayName)")
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Previews

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Full settings view
            SettingsView()
                .environmentObject(makePreviewSettings())
                .environmentObject(DisplayTracker())
                .environmentObject(LaunchAtLoginManager())
                .previewDisplayName("Settings")

            // Appearance tab only
            AppearanceTab()
                .environmentObject(makePreviewSettings())
                .frame(width: 400, height: 400)
                .previewDisplayName("Appearance")

            // Behavior tab only
            BehaviorTab()
                .environmentObject(makePreviewSettings())
                .environmentObject(LaunchAtLoginManager())
                .frame(width: 400, height: 300)
                .previewDisplayName("Behavior")
        }
    }

    static func makePreviewSettings() -> SettingsStore {
        // swiftlint:disable:next force_unwrapping
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "preview")!)
        settings.aliases["1"] = "MacBook Pro"
        settings.displayColors["1"] = "#007AFF"
        return settings
    }
}
#endif
