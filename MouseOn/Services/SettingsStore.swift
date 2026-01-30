//
//  SettingsStore.swift
//  MouseOn
//
//  Manages app settings persistence using UserDefaults.
//

import SwiftUI
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "SettingsStore")

// MARK: - Settings Store

/// Observable settings store that persists to UserDefaults
///
/// Thread Safety: This class is `@MainActor` isolated. All property access
/// and method calls are guaranteed to happen on the main thread.
@MainActor
final class SettingsStore: ObservableObject {

    // MARK: - Published Properties

    @Published var features = FeatureToggles()
    @Published var opacity: Double = Constants.Defaults.opacity
    @Published var autoHideSeconds: Int = Constants.Defaults.autoHideSeconds
    @Published var aliases: [String: String] = [:]
    @Published var maxNameLength: Int = Constants.Defaults.maxNameLength
    @Published var displayColors: [String: String] = [:]
    @Published var useSingleAccentColor: Bool = false
    @Published var singleAccentColor: String = Constants.Defaults.accentColor
    @Published var highlightColor: String = Constants.Defaults.highlightColor
    @Published var findCursorHotkeyEnabled: Bool = true
    @Published var largeCursorDuration: Double = Constants.Defaults.largeCursorDuration
    @Published var largeCursorSize: Double = Constants.Defaults.largeCursorSize

    // MARK: - Private Properties

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Public Methods

    /// Load settings from UserDefaults
    func load() {
        logger.debug("Loading settings from UserDefaults")

        // Load feature toggles
        if let data = defaults.data(forKey: Constants.UserDefaultsKeys.features) {
            do {
                features = try JSONDecoder().decode(FeatureToggles.self, from: data)
                logger.debug("Loaded feature toggles")
            } catch {
                logger.error("Failed to decode feature toggles: \(error.localizedDescription)")
            }
        }

        // Load opacity
        let storedOpacity = defaults.double(forKey: Constants.UserDefaultsKeys.opacity)
        opacity = storedOpacity == 0
            ? Constants.Defaults.opacity
            : storedOpacity.clamped(to: Constants.Defaults.opacityRange)

        // Load auto-hide seconds
        let storedSecs = defaults.integer(forKey: Constants.UserDefaultsKeys.autoHideSeconds)
        autoHideSeconds = storedSecs == 0
            ? Constants.Defaults.autoHideSeconds
            : storedSecs.clamped(to: Constants.Defaults.autoHideRange)

        // Load aliases
        if let aliasData = defaults.dictionary(forKey: Constants.UserDefaultsKeys.aliases) as? [String: String] {
            aliases = aliasData
        }

        // Load max name length
        let storedLen = defaults.integer(forKey: Constants.UserDefaultsKeys.maxNameLength)
        maxNameLength = Constants.Defaults.nameLengthRange.contains(storedLen)
            ? storedLen
            : Constants.Defaults.maxNameLength

        // Load display colors
        if let colorData = defaults.dictionary(forKey: Constants.UserDefaultsKeys.displayColors) as? [String: String] {
            displayColors = colorData
        }

        // Load single accent color settings
        useSingleAccentColor = defaults.bool(forKey: Constants.UserDefaultsKeys.useSingleAccentColor)
        let accentKey = Constants.UserDefaultsKeys.singleAccentColor
        if let storedAccent = defaults.string(forKey: accentKey),
           !storedAccent.isEmpty {
            singleAccentColor = storedAccent
        }

        // Load highlight color
        let highlightKey = Constants.UserDefaultsKeys.highlightColor
        if let storedHighlight = defaults.string(forKey: highlightKey),
           !storedHighlight.isEmpty {
            highlightColor = storedHighlight
        }

        // Load hotkey setting (defaults to true)
        if defaults.object(forKey: Constants.UserDefaultsKeys.findCursorHotkeyEnabled) != nil {
            findCursorHotkeyEnabled = defaults.bool(forKey: Constants.UserDefaultsKeys.findCursorHotkeyEnabled)
        }

        // Load large cursor settings
        let storedDuration = defaults.double(forKey: Constants.UserDefaultsKeys.largeCursorDuration)
        largeCursorDuration = storedDuration == 0
            ? Constants.Defaults.largeCursorDuration
            : storedDuration.clamped(to: Constants.Defaults.largeCursorDurationRange)

        let storedSize = defaults.double(forKey: Constants.UserDefaultsKeys.largeCursorSize)
        largeCursorSize = storedSize == 0
            ? Constants.Defaults.largeCursorSize
            : storedSize.clamped(to: Constants.Defaults.largeCursorSizeRange)

        logger.info("Settings loaded successfully")
    }

    /// Save settings to UserDefaults
    func save() {
        logger.debug("Saving settings to UserDefaults")

        do {
            let featuresData = try JSONEncoder().encode(features)
            defaults.set(featuresData, forKey: Constants.UserDefaultsKeys.features)
        } catch {
            logger.error("Failed to encode feature toggles: \(error.localizedDescription)")
        }

        defaults.set(opacity, forKey: Constants.UserDefaultsKeys.opacity)
        defaults.set(autoHideSeconds, forKey: Constants.UserDefaultsKeys.autoHideSeconds)
        defaults.set(aliases, forKey: Constants.UserDefaultsKeys.aliases)
        defaults.set(maxNameLength, forKey: Constants.UserDefaultsKeys.maxNameLength)
        defaults.set(displayColors, forKey: Constants.UserDefaultsKeys.displayColors)
        defaults.set(useSingleAccentColor, forKey: Constants.UserDefaultsKeys.useSingleAccentColor)
        defaults.set(singleAccentColor, forKey: Constants.UserDefaultsKeys.singleAccentColor)
        defaults.set(highlightColor, forKey: Constants.UserDefaultsKeys.highlightColor)
        defaults.set(findCursorHotkeyEnabled, forKey: Constants.UserDefaultsKeys.findCursorHotkeyEnabled)
        defaults.set(largeCursorDuration, forKey: Constants.UserDefaultsKeys.largeCursorDuration)
        defaults.set(largeCursorSize, forKey: Constants.UserDefaultsKeys.largeCursorSize)

        logger.info("Settings saved successfully")
    }

    /// Get Color for a display ID
    /// - Parameter displayID: The display identifier
    /// - Returns: The color if set, or single accent color if enabled
    func colorForDisplay(_ displayID: String) -> Color? {
        if useSingleAccentColor {
            return Color(hex: singleAccentColor) ?? .accentColor
        }
        guard let hex = displayColors[displayID] else { return nil }
        return Color(hex: hex)
    }

    /// Get the highlight color as NSColor
    /// - Returns: The configured highlight color or system orange
    func getHighlightNSColor() -> NSColor {
        if let color = Color(hex: highlightColor) {
            return NSColor(color)
        }
        return .systemOrange
    }
}
