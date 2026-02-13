//
//  MouseOnTests.swift
//  MouseOnTests
//
//  Comprehensive unit tests for MouseOn app
//  Migrated to Swift Testing framework
//

import Testing
import SwiftUI
import Combine
@testable import MouseOn

// MARK: - Settings Store Tests

@Suite("Settings Store")
@MainActor
struct SettingsStoreTests {

    let settings: SettingsStore
    let testDefaults: UserDefaults

    init() {
        testDefaults = UserDefaults(suiteName: "com.mouseon.tests.\(UUID().uuidString)")!
        settings = SettingsStore(defaults: testDefaults)
    }

    // MARK: - Default Values

    @Test("Default opacity matches constant")
    func defaultOpacity() {
        #expect(settings.opacity == Constants.Defaults.opacity)
    }

    @Test("Default auto-hide seconds matches constant")
    func defaultAutoHideSeconds() {
        #expect(settings.autoHideSeconds == Constants.Defaults.autoHideSeconds)
    }

    @Test("Default max name length matches constant")
    func defaultMaxNameLength() {
        #expect(settings.maxNameLength == Constants.Defaults.maxNameLength)
    }

    @Test("Default feature toggles are correct")
    func defaultFeatureToggles() {
        #expect(settings.features.showDataBox == true)
        #expect(settings.features.autoHideEnabled == false)
        #expect(settings.features.statsEnabled == true)
    }

    @Test("Default highlight color matches constant")
    func defaultHighlightColor() {
        #expect(settings.highlightColor == Constants.Defaults.highlightColor)
    }

    @Test("Find cursor hotkey enabled by default")
    func defaultFindCursorHotkeyEnabled() {
        #expect(settings.findCursorHotkeyEnabled == true)
    }

    // MARK: - Aliases

    @Test("Set and get alias")
    func setAndGetAlias() {
        settings.aliases["test-display"] = "My Display"
        #expect(settings.aliases["test-display"] == "My Display")
    }

    @Test("Alias with emoji")
    func aliasWithEmoji() {
        settings.aliases["test-display"] = "🖥️ Main"
        #expect(settings.aliases["test-display"] == "🖥️ Main")
    }

    @Test("Universal Control alias")
    func universalControlAlias() {
        settings.aliases[Constants.SpecialKeys.universalControl] = "📱 iPad Pro"
        #expect(settings.aliases[Constants.SpecialKeys.universalControl] == "📱 iPad Pro")
    }

    @Test("Alias removal")
    func aliasRemoval() {
        settings.aliases["test-display"] = "Test"
        settings.aliases.removeValue(forKey: "test-display")
        #expect(settings.aliases["test-display"] == nil)
    }

    // MARK: - Colors

    @Test("Set and get display color")
    func setAndGetDisplayColor() {
        settings.displayColors["test-display"] = "#FF5733"
        #expect(settings.displayColors["test-display"] == "#FF5733")
    }

    @Test("Color for unset display returns nil")
    func colorForDisplayReturnsNil() {
        settings.useSingleAccentColor = false
        #expect(settings.colorForDisplay("nonexistent") == nil)
    }

    @Test("Color for set display returns value")
    func colorForDisplayReturnsColor() {
        settings.useSingleAccentColor = false
        settings.displayColors["test-display"] = "#FF0000"
        #expect(settings.colorForDisplay("test-display") != nil)
    }

    @Test("Single accent color overrides per-display color")
    func colorForDisplayReturnsSingleAccent() {
        settings.useSingleAccentColor = true
        settings.singleAccentColor = "#00FF00"
        #expect(settings.colorForDisplay("any-display") != nil)
    }

    @Test("Highlight NSColor is returned")
    func getHighlightNSColor() {
        settings.highlightColor = "#FF9500"
        #expect(settings.getHighlightNSColor() != nil)
    }

    // MARK: - Persistence

    @Test("Save and load aliases")
    func saveAndLoadAliases() {
        settings.aliases["persist-test"] = "Persisted Name"
        settings.save()
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.aliases["persist-test"] == "Persisted Name")
    }

    @Test("Save and load colors")
    func saveAndLoadColors() {
        settings.displayColors["persist-test"] = "#00FF00"
        settings.save()
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.displayColors["persist-test"] == "#00FF00")
    }

    @Test("Save and load opacity")
    func saveAndLoadOpacity() {
        settings.opacity = 0.5
        settings.save()
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.opacity == 0.5)
    }

    @Test("Save and load single accent color")
    func saveAndLoadSingleAccentColor() {
        settings.useSingleAccentColor = true
        settings.singleAccentColor = "#123456"
        settings.save()
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.useSingleAccentColor == true)
        #expect(loaded.singleAccentColor == "#123456")
    }

    // MARK: - Clamping

    @Test("Opacity above range clamped to upper bound")
    func opacityClampedAbove() {
        testDefaults.set(2.0, forKey: Constants.UserDefaultsKeys.opacity)
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.opacity <= Constants.Defaults.opacityRange.upperBound)
    }

    @Test("Opacity below range clamped to lower bound")
    func opacityClampedBelow() {
        testDefaults.set(0.1, forKey: Constants.UserDefaultsKeys.opacity)
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.opacity >= Constants.Defaults.opacityRange.lowerBound)
    }
}

// MARK: - Color Extension Tests

@Suite("Color+Hex Extension")
struct ColorExtensionTests {

    @Test("Color from valid hex string")
    func colorFromValidHex() {
        #expect(Color(hex: "#FF0000") != nil)
    }

    @Test("Color from hex without # prefix")
    func colorFromHexWithoutHash() {
        #expect(Color(hex: "00FF00") != nil)
    }

    @Test("Invalid hex returns nil")
    func colorFromInvalidHex() {
        #expect(Color(hex: "not-a-color") == nil)
    }

    @Test("Empty string returns nil")
    func colorFromEmptyString() {
        #expect(Color(hex: "") == nil)
    }

    @Test("Short hex doesn't crash")
    func colorFromShortHex() {
        // 3-char hex parses but produces unexpected color since we expect 6 chars
        _ = Color(hex: "#FFF")
    }

    @Test("Color to hex produces valid format")
    func colorToHex() throws {
        let color = try #require(Color(hex: "#FF0000"))
        let hex = try #require(color.toHex())
        #expect(hex.hasPrefix("#"))
        #expect(hex.count == 7)
    }

    @Test("Color hex round trip preserves format")
    func colorRoundTrip() throws {
        let color = try #require(Color(hex: "#3498DB"))
        let resultHex = try #require(color.toHex())
        #expect(resultHex.count == 7)
    }
}

// MARK: - Stats Manager Tests

@Suite("Stats Manager")
@MainActor
struct StatsManagerTests {

    let stats: StatsManager

    init() {
        stats = StatsManager()
        stats.resetStats()
    }

    @Test("Initial stats are empty after reset")
    func initialStatsEmpty() async throws {
        try await Task.sleep(for: .milliseconds(150))
        #expect(stats.data.isEmpty)
    }

    @Test("Initial switch count is zero")
    func initialSwitchCountZero() {
        #expect(stats.totalSwitches == 0)
    }

    @Test("Recording a switch increments count")
    func recordSwitchIncrementsCount() async throws {
        stats.record(switchTo: "Display 1")
        try await Task.sleep(for: .milliseconds(150))
        #expect(stats.totalSwitches == 1)
    }

    @Test("Multiple switches are tracked")
    func recordMultipleSwitches() async throws {
        stats.record(switchTo: "Display 1")
        stats.record(switchTo: "Display 2")
        stats.record(switchTo: "Display 1")
        try await Task.sleep(for: .milliseconds(250))
        #expect(stats.totalSwitches == 3)
    }

    @Test("Reset clears all stats")
    func resetStats() async throws {
        stats.record(switchTo: "Display 1")
        stats.record(switchTo: "Display 2")
        try await Task.sleep(for: .milliseconds(150))
        stats.resetStats()
        try await Task.sleep(for: .milliseconds(150))
        #expect(stats.data.isEmpty)
        #expect(stats.totalSwitches == 0)
    }

    @Test("Flush updates display time data")
    func flushUpdatesData() async throws {
        stats.record(switchTo: "Display 1")
        try await Task.sleep(for: .milliseconds(200))
        stats.flush()
        try await Task.sleep(for: .milliseconds(150))
        #expect(stats.data["Display 1"] != nil)
        #expect((stats.data["Display 1"] ?? 0) > 0)
    }

    @Test("Sequential switches record time for each display")
    func recordSequentialSwitches() async throws {
        stats.record(switchTo: "Display 1")
        try await Task.sleep(for: .milliseconds(100))
        stats.record(switchTo: "Display 2")
        try await Task.sleep(for: .milliseconds(100))
        stats.record(switchTo: "Display 1")
        try await Task.sleep(for: .milliseconds(250))
        #expect(stats.data["Display 1"] != nil)
    }
}

// MARK: - Edge Detection Tests

@Suite("Edge Detection")
struct EdgeDetectionTests {

    func isAtEdge(_ point: NSPoint, screens: [NSRect], threshold: CGFloat = Constants.Display.edgeThreshold) -> Bool {
        for screen in screens {
            let atLeft = abs(point.x - screen.minX) < threshold
            let atRight = abs(point.x - screen.maxX) < threshold
            let atTop = abs(point.y - screen.maxY) < threshold
            let atBottom = abs(point.y - screen.minY) < threshold
            if atLeft || atRight || atTop || atBottom { return true }
        }
        return false
    }

    static let standardScreen = NSRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("Point at left edge detected", arguments: [
        NSPoint(x: 2, y: 500),
    ])
    func pointAtLeftEdge(point: NSPoint) {
        #expect(isAtEdge(point, screens: [Self.standardScreen]))
    }

    @Test("Point at right edge detected")
    func pointAtRightEdge() {
        #expect(isAtEdge(NSPoint(x: 1918, y: 500), screens: [Self.standardScreen]))
    }

    @Test("Point at top edge detected")
    func pointAtTopEdge() {
        #expect(isAtEdge(NSPoint(x: 960, y: 1078), screens: [Self.standardScreen]))
    }

    @Test("Point at bottom edge detected")
    func pointAtBottomEdge() {
        #expect(isAtEdge(NSPoint(x: 960, y: 2), screens: [Self.standardScreen]))
    }

    @Test("Point in center not at edge")
    func pointInCenter() {
        #expect(!isAtEdge(NSPoint(x: 960, y: 540), screens: [Self.standardScreen]))
    }

    @Test("Point at corner detected")
    func pointAtCorner() {
        #expect(isAtEdge(NSPoint(x: 0, y: 0), screens: [Self.standardScreen]))
    }

    @Test("Multi-screen edge detection")
    func multipleScreens() {
        let screen1 = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let screen2 = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        #expect(isAtEdge(NSPoint(x: 1918, y: 500), screens: [screen1, screen2]))
    }

    @Test("Custom threshold affects detection")
    func customThreshold() {
        let point = NSPoint(x: 10, y: 500)
        #expect(!isAtEdge(point, screens: [Self.standardScreen], threshold: 5))
        #expect(isAtEdge(point, screens: [Self.standardScreen], threshold: 15))
    }
}

// MARK: - Clamped Extension Tests

@Suite("Comparable+Clamped Extension")
struct ClampedExtensionTests {

    @Test("Values clamped correctly", arguments: [
        (50, 0, 100, 50),
        (-10, 0, 100, 0),
        (150, 0, 100, 100),
        (0, 0, 100, 0),
        (100, 0, 100, 100),
    ])
    func clampedInt(value: Int, lower: Int, upper: Int, expected: Int) {
        #expect(value.clamped(to: lower...upper) == expected)
    }

    @Test("Double clamped to upper bound")
    func clampedDouble() {
        #expect(1.5.clamped(to: 0.0...1.0) == 1.0)
    }

    @Test("Value clamped in negative range")
    func clampedNegativeRange() {
        #expect(0.clamped(to: -10...(-1)) == -1)
    }
}

// MARK: - Display Info Tests

@Suite("Display Info")
struct DisplayInfoTests {

    @Test("Sidecar detected with Apple vendor + virtual model")
    func sidecarWithAppleVendor() {
        #expect(DisplayInfo.isSidecarDisplay(vendorID: 0x610, modelID: 0xA030, isBuiltin: false))
    }

    @Test("Sidecar detected with alternate Apple vendor ID")
    func sidecarWithAltAppleVendor() {
        #expect(DisplayInfo.isSidecarDisplay(vendorID: 1552, modelID: 0xA030, isBuiltin: false))
    }

    @Test("Built-in display not detected as Sidecar")
    func sidecarNotBuiltIn() {
        #expect(!DisplayInfo.isSidecarDisplay(vendorID: 0x610, modelID: 0xA030, isBuiltin: true))
    }

    @Test("Non-Apple vendor not detected as Sidecar")
    func sidecarNotNonApple() {
        #expect(!DisplayInfo.isSidecarDisplay(vendorID: 0x123, modelID: 0xA030, isBuiltin: false))
    }

    @Test("Normal model ID not detected as Sidecar")
    func sidecarNotNormalModel() {
        #expect(!DisplayInfo.isSidecarDisplay(vendorID: 0x610, modelID: 0x1234, isBuiltin: false))
    }

    @Test("Name hints detect Sidecar-related names", arguments: [
        ("Sidecar Display", true),
        ("iPad Pro", true),
        ("My IPAD", true),
        ("SIDECAR", true),
        ("Dell Monitor", false),
        ("Built-in Display", false),
        ("Studio Display", false),
    ])
    func nameHintsSidecar(name: String, expected: Bool) {
        #expect(DisplayInfo.nameHintsSidecar(name) == expected)
    }
}

// MARK: - Constants Tests

@Suite("Constants")
struct ConstantsTests {

    @Test("Timing constants are positive")
    func timingConstantsPositive() {
        #expect(Constants.Timing.fastPollingInterval > 0)
        #expect(Constants.Timing.slowPollingInterval > 0)
        #expect(Constants.Timing.displayRefreshInterval > 0)
        #expect(Constants.Timing.highlightAnimationInterval > 0)
        #expect(Constants.Timing.highlightDismissDelay > 0)
    }

    @Test("Fast polling is faster than slow polling")
    func fastPollingFasterThanSlow() {
        #expect(Constants.Timing.fastPollingInterval < Constants.Timing.slowPollingInterval)
    }

    @Test("Default values fall within their ranges")
    func defaultsInRange() {
        #expect(Constants.Defaults.opacityRange.contains(Constants.Defaults.opacity))
        #expect(Constants.Defaults.autoHideRange.contains(Constants.Defaults.autoHideSeconds))
        #expect(Constants.Defaults.nameLengthRange.contains(Constants.Defaults.maxNameLength))
    }

    @Test("Opacity range is within 0...1")
    func opacityRangeReasonable() {
        #expect(Constants.Defaults.opacityRange.lowerBound >= 0)
        #expect(Constants.Defaults.opacityRange.upperBound <= 1.0)
    }

    @Test("Apple vendor IDs contain known values")
    func appleVendorIDs() {
        #expect(!Constants.Display.appleVendorIDs.isEmpty)
        #expect(Constants.Display.appleVendorIDs.contains(0x610))
        #expect(Constants.Display.appleVendorIDs.contains(1552))
    }

    @Test("UserDefaults keys are all unique")
    func userDefaultsKeysUnique() {
        let keys = [
            Constants.UserDefaultsKeys.features,
            Constants.UserDefaultsKeys.opacity,
            Constants.UserDefaultsKeys.autoHideSeconds,
            Constants.UserDefaultsKeys.aliases,
            Constants.UserDefaultsKeys.maxNameLength,
            Constants.UserDefaultsKeys.displayColors,
            Constants.UserDefaultsKeys.useSingleAccentColor,
            Constants.UserDefaultsKeys.singleAccentColor,
            Constants.UserDefaultsKeys.highlightColor,
            Constants.UserDefaultsKeys.findCursorHotkeyEnabled,
        ]
        #expect(Set(keys).count == keys.count)
    }
}

// MARK: - Feature Toggles Tests

@Suite("Feature Toggles")
struct FeatureTogglesTests {

    @Test("Default values are correct")
    func defaultValues() {
        let toggles = FeatureToggles()
        #expect(toggles.showDataBox == true)
        #expect(toggles.autoHideEnabled == false)
        #expect(toggles.statsEnabled == true)
    }

    @Test("Codable round trip preserves defaults")
    func codableRoundTrip() throws {
        let original = FeatureToggles()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeatureToggles.self, from: data)
        #expect(decoded.showDataBox == original.showDataBox)
        #expect(decoded.autoHideEnabled == original.autoHideEnabled)
        #expect(decoded.statsEnabled == original.statsEnabled)
    }

    @Test("Codable round trip preserves modified values")
    func codableWithModifiedValues() throws {
        var original = FeatureToggles()
        original.showDataBox = false
        original.autoHideEnabled = true
        original.statsEnabled = false

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeatureToggles.self, from: data)
        #expect(decoded.showDataBox == false)
        #expect(decoded.autoHideEnabled == true)
        #expect(decoded.statsEnabled == false)
    }
}

// MARK: - Power State Monitor Tests

@Suite("Power State Monitor")
@MainActor
struct PowerStateMonitorTests {

    @Test("Monitor initializes without crash")
    func monitorInitializes() {
        let monitor = PowerStateMonitor()
        #expect(monitor != nil)
    }

    @Test("Monitor publishes property values")
    func monitorPublishesValues() {
        let monitor = PowerStateMonitor()
        _ = monitor.isOnBattery
        _ = monitor.batteryLevel
        _ = monitor.isLowPowerMode
    }

    @Test("Refresh does not crash")
    func refreshDoesNotCrash() {
        let monitor = PowerStateMonitor()
        monitor.refresh()
    }
}

// MARK: - App Dependencies Tests

@Suite("App Dependencies")
@MainActor
struct AppDependenciesTests {

    @Test("Dependencies initialize with all services")
    func dependenciesInitialize() {
        let deps = AppDependencies()
        #expect(deps.settings != nil)
        #expect(deps.stats != nil)
        #expect(deps.tracker != nil)
        #expect(deps.launchAtLogin != nil)
        #expect(deps.powerMonitor != nil)
    }

    @Test("Dependencies accept custom settings")
    func dependenciesWithCustomSettings() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.deps.test")!
        let settings = SettingsStore(defaults: testDefaults)
        settings.opacity = 0.5
        let deps = AppDependencies(settings: settings, userDefaults: testDefaults)
        #expect(deps.settings.opacity == 0.5)
    }
}

// MARK: - Display Tracker Tests

@Suite("Display Tracker")
@MainActor
struct DisplayTrackerTests {

    @Test("Tracker initializes with empty state")
    func trackerInitializes() {
        let tracker = DisplayTracker()
        #expect(tracker.currentName == "")
        #expect(tracker.currentDisplayID == nil)
        #expect(tracker.isOnUniversalControl == false)
    }

    @Test("Tracker can refresh display list without crash")
    func trackerCanRefreshDisplayList() {
        let tracker = DisplayTracker()
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let stats = StatsManager()
        tracker.inject(settings: settings, stats: stats)
        tracker.refreshDisplayList()
        #expect(tracker.allDisplays != nil)
    }

    @Test("Update polling mode does not crash")
    func updatePollingMode() {
        let tracker = DisplayTracker()
        tracker.updatePollingMode(conservePower: true)
        tracker.updatePollingMode(conservePower: false)
    }
}
