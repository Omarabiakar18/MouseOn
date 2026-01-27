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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabView {
                AppearanceTab()
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                    .accessibilityIdentifier("appearanceTab")

                BehaviorTab()
                    .tabItem { Label("Behavior", systemImage: "gearshape") }
                    .accessibilityIdentifier("behaviorTab")

                DisplaysTab()
                    .tabItem { Label("Displays", systemImage: "display.2") }
                    .accessibilityIdentifier("displaysTab")
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 340)
    }
}

// MARK: - Appearance Tab

/// Settings for visual appearance and Find My Cursor feature
struct AppearanceTab: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            // Display name length
            Section {
                displayedCharactersSection
            }

            // Opacity control
            Section {
                opacitySection
            }

            // Color mode
            Section("Display Colors") {
                colorModeSection
            }

            // Find My Cursor
            Section("Find My Cursor") {
                findMyCursorSection
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu bar opacity")
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
        Toggle(
            "Use single accent color for all displays",
            isOn: $settings.useSingleAccentColor
        )
        .accessibilityIdentifier("singleAccentColorToggle")

        if settings.useSingleAccentColor {
            ColorPicker(
                "Accent color",
                selection: Binding(
                    get: { Color(hex: settings.singleAccentColor) ?? .accentColor },
                    set: { settings.singleAccentColor = $0.toHex() ?? Constants.Defaults.accentColor }
                )
            )
            .accessibilityIdentifier("accentColorPicker")
        } else {
            Text("Configure per-display colors in the Displays tab")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var findMyCursorSection: some View {
        ColorPicker(
            "Highlight color",
            selection: Binding(
                get: { Color(hex: settings.highlightColor) ?? .orange },
                set: { settings.highlightColor = $0.toHex() ?? Constants.Defaults.highlightColor }
            )
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
                    .background(Color.secondary.opacity(0.2))
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
        VStack(alignment: .leading, spacing: 8) {
            Text("When your cursor moves to an iPad via Universal Control, it will show this name:")
                .font(.caption)
                .foregroundColor(.secondary)

            DisplayRow(
                displayName: "iPad (via Universal Control)",
                displayID: Constants.SpecialKeys.universalControl,
                icon: "ipad"
            )
        }
    }
}

// MARK: - Display Row

/// A row for configuring a single display's alias and color
struct DisplayRow: View {
    @EnvironmentObject var settings: SettingsStore

    let displayName: String
    let displayID: String
    var icon: String? = nil

    private var nameBinding: Binding<String> {
        Binding(
            get: { settings.aliases[displayID] ?? "" },
            set: { newValue in
                if newValue.isEmpty {
                    settings.aliases.removeValue(forKey: displayID)
                } else {
                    settings.aliases[displayID] = newValue
                }
            }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { settings.colorForDisplay(displayID) ?? .primary },
            set: { settings.displayColors[displayID] = $0.toHex() }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // Display info
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                }
                Text(displayName)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Color picker
            ColorPicker("", selection: colorBinding)
                .labelsHidden()
                .frame(width: 32)
                .accessibilityLabel("Color for \(displayName)")

            // Alias field
            TextField("Custom name", text: nameBinding)
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)
                .accessibilityLabel("Alias for \(displayName)")

            // Emoji picker button
            Button(action: { NSApp.orderFrontCharacterPalette(nil) }) {
                Image(systemName: "face.smiling")
            }
            .buttonStyle(.borderless)
            .help("Open Emoji Picker")
            .accessibilityLabel("Open emoji picker for \(displayName)")
        }
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
