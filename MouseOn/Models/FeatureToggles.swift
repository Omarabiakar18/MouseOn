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
    /// Whether to show the data box (currently unused)
    var showDataBox: Bool = true

    /// Whether auto-hide is enabled for the menu bar item
    var autoHideEnabled: Bool = false

    /// Whether statistics collection is enabled
    var statsEnabled: Bool = true
}
