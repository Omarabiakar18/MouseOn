//
//  FeatureToggles.swift
//  MouseOn
//
//  Model for app feature toggles stored in settings.
//

import Foundation

// MARK: - Feature Toggles

/// Represents toggleable features in the app
struct FeatureToggles: Codable {
    /// Whether auto-hide is enabled for the menu bar item
    var autoHideEnabled: Bool = false

    /// Whether statistics collection is enabled
    var statsEnabled: Bool = true

    /// Whether to show emoji instead of display name in menu bar
    var emojiModeEnabled: Bool = false

    /// Whether large cursor mode hotkey is enabled
    var largeCursorEnabled: Bool = true
}
