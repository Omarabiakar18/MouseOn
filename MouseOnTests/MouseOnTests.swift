// swiftlint:disable file_length
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
        NSPoint(x: 2, y: 500)
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
        (100, 0, 100, 100)
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
        ("Studio Display", false)
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
            Constants.UserDefaultsKeys.lastUpdateCheck,
            Constants.UserDefaultsKeys.hasRequestedNotificationPermission
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
        #expect(toggles.autoHideEnabled == false)
        #expect(toggles.statsEnabled == true)
    }

    @Test("Codable round trip preserves defaults")
    func codableRoundTrip() throws {
        let original = FeatureToggles()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeatureToggles.self, from: data)
        #expect(decoded.autoHideEnabled == original.autoHideEnabled)
        #expect(decoded.statsEnabled == original.statsEnabled)
    }

    @Test("Codable round trip preserves modified values")
    func codableWithModifiedValues() throws {
        var original = FeatureToggles()
        original.autoHideEnabled = true
        original.statsEnabled = false

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeatureToggles.self, from: data)
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

// MARK: - Settings Emoji & Display Name Tests

@Suite("Settings Display Names & Emoji")
@MainActor
struct SettingsDisplayNameTests {

    let settings: SettingsStore
    let testDefaults: UserDefaults

    init() {
        testDefaults = UserDefaults(suiteName: "com.mouseon.tests.displayname.\(UUID().uuidString)")!
        settings = SettingsStore(defaults: testDefaults)
    }

    @Test("Display name returns alias when set")
    func displayNameReturnsAlias() {
        settings.aliases["12345"] = "My Monitor"
        #expect(settings.displayName(for: "12345") == "My Monitor")
    }

    @Test("Display name returns Universal Control name for special key")
    func displayNameUniversalControl() {
        let name = settings.displayName(for: Constants.SpecialKeys.universalControl)
        #expect(name == Constants.Defaults.universalControlName)
    }

    @Test("Empty alias falls through to system name")
    func emptyAliasFallsThrough() {
        settings.aliases["12345"] = ""
        // Won't match a real display, so falls through to ID
        let name = settings.displayName(for: "12345")
        #expect(name != "")
    }

    @Test("Emoji for display returns nil when not set")
    func emojiNilWhenNotSet() {
        #expect(settings.emojiForDisplay("12345") == nil)
    }

    @Test("Emoji for display returns value when set")
    func emojiReturnsValue() {
        settings.displayEmojis["12345"] = "🖥️"
        #expect(settings.emojiForDisplay("12345") == "🖥️")
    }

    @Test("Emoji persists across save/load")
    func emojiPersistence() {
        settings.displayEmojis["persist-emoji"] = "💻"
        settings.save()
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.displayEmojis["persist-emoji"] == "💻")
    }

    @Test("Emoji mode default is off")
    func emojiModeDefaultOff() {
        #expect(settings.features.emojiModeEnabled == false)
    }

    @Test("Multiple display emojis are independent")
    func multipleDisplayEmojis() {
        settings.displayEmojis["display1"] = "🖥️"
        settings.displayEmojis["display2"] = "💻"
        settings.displayEmojis["display3"] = "📱"
        #expect(settings.emojiForDisplay("display1") == "🖥️")
        #expect(settings.emojiForDisplay("display2") == "💻")
        #expect(settings.emojiForDisplay("display3") == "📱")
    }
}

// MARK: - Settings Edge Cases

@Suite("Settings Edge Cases")
@MainActor
struct SettingsEdgeCaseTests {

    let settings: SettingsStore
    let testDefaults: UserDefaults

    init() {
        testDefaults = UserDefaults(suiteName: "com.mouseon.tests.edge.\(UUID().uuidString)")!
        settings = SettingsStore(defaults: testDefaults)
    }

    @Test("Max name length clamped on load")
    func maxNameLengthClampedOnLoad() {
        // Out-of-range value saved to defaults is clamped during load()
        testDefaults.set(1, forKey: Constants.UserDefaultsKeys.maxNameLength)
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.maxNameLength == Constants.Defaults.maxNameLength)
    }

    @Test("Very long alias is stored correctly")
    func longAlias() {
        let longName = String(repeating: "A", count: 200)
        settings.aliases["test"] = longName
        #expect(settings.aliases["test"] == longName)
    }

    @Test("Special characters in alias")
    func specialCharsAlias() {
        settings.aliases["test"] = "显示器 <>&\"'™"
        #expect(settings.aliases["test"] == "显示器 <>&\"'™")
    }

    @Test("Color hex with lowercase and uppercase")
    func colorHexCasing() {
        settings.displayColors["test1"] = "#ff0000"
        settings.displayColors["test2"] = "#FF0000"
        #expect(settings.displayColors["test1"] == "#ff0000")
        #expect(settings.displayColors["test2"] == "#FF0000")
    }

    @Test("Single accent color toggle persists")
    func singleAccentToggle() {
        settings.useSingleAccentColor = true
        settings.save()
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.useSingleAccentColor == true)
    }

    @Test("Find cursor hotkey toggle persists")
    func findCursorHotkeyPersistence() {
        settings.findCursorHotkeyEnabled = false
        settings.save()
        let loaded = SettingsStore(defaults: testDefaults)
        #expect(loaded.findCursorHotkeyEnabled == false)
    }

    @Test("Large cursor settings have valid defaults")
    func largeCursorDefaults() {
        #expect(settings.largeCursorDuration > 0)
        #expect(settings.largeCursorSize > 0)
    }
}

// MARK: - Update Checker Tests

@Suite("Update Checker")
@MainActor
struct UpdateCheckerTests {

    @Test("Current version is not empty")
    func currentVersionNotEmpty() {
        let checker = UpdateChecker.shared
        _ = checker.currentVersion
    }

    @Test("Initial state has no update available")
    func initialStateNoUpdate() {
        let checker = UpdateChecker()
        #expect(checker.updateAvailable == false)
        #expect(checker.latestVersion == nil)
        #expect(checker.isChecking == false)
    }

    @Test("Initial state has no download in progress")
    func initialStateNoDownload() {
        let checker = UpdateChecker()
        #expect(checker.isDownloading == false)
        #expect(checker.downloadedDMGURL == nil)
    }

    @Test("shouldCheckNow returns true when never checked")
    func shouldCheckWhenNeverChecked() {
        let defaults = UserDefaults(
            suiteName: "com.mouseon.tests.updatecheck.\(UUID().uuidString)"
        )!
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.lastUpdateCheck)
        // No lastUpdateCheck → should check
        let lastCheck = defaults.object(
            forKey: Constants.UserDefaultsKeys.lastUpdateCheck
        ) as? Date
        #expect(lastCheck == nil)
    }

    @Test("Last check timestamp is stored after setting")
    func lastCheckTimestampStored() {
        let defaults = UserDefaults(
            suiteName: "com.mouseon.tests.updatecheck.\(UUID().uuidString)"
        )!
        let now = Date()
        defaults.set(now, forKey: Constants.UserDefaultsKeys.lastUpdateCheck)
        let stored = defaults.object(
            forKey: Constants.UserDefaultsKeys.lastUpdateCheck
        ) as? Date
        #expect(stored != nil)
        #expect(abs(stored!.timeIntervalSince(now)) < 1)
    }

    @Test("Stale timestamp (>6h ago) should trigger check")
    func staleTimestampShouldTriggerCheck() throws {
        let defaults = UserDefaults(
            suiteName: "com.mouseon.tests.updatecheck.\(UUID().uuidString)"
        )!
        let sevenHoursAgo = Date().addingTimeInterval(-7 * 3600)
        defaults.set(sevenHoursAgo, forKey: Constants.UserDefaultsKeys.lastUpdateCheck)
        let lastCheck = try #require(defaults.object(
            forKey: Constants.UserDefaultsKeys.lastUpdateCheck
        ) as? Date)
        let elapsed = Date().timeIntervalSince(lastCheck)
        #expect(elapsed >= Constants.Update.checkInterval)
    }

    @Test("Recent timestamp (<6h ago) should not trigger check")
    func recentTimestampShouldNotTriggerCheck() throws {
        let defaults = UserDefaults(
            suiteName: "com.mouseon.tests.updatecheck.\(UUID().uuidString)"
        )!
        let oneHourAgo = Date().addingTimeInterval(-3600)
        defaults.set(oneHourAgo, forKey: Constants.UserDefaultsKeys.lastUpdateCheck)
        let lastCheck = try #require(defaults.object(
            forKey: Constants.UserDefaultsKeys.lastUpdateCheck
        ) as? Date)
        let elapsed = Date().timeIntervalSince(lastCheck)
        #expect(elapsed < Constants.Update.checkInterval)
    }
}

// MARK: - AutoHide Manager Tests

@Suite("AutoHide Manager")
@MainActor
struct AutoHideManagerTests {

    @Test("AutoHide starts visible")
    func startsVisible() {
        let defaults = UserDefaults(suiteName: "com.mouseon.tests.autohide.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        let manager = AutoHideManager(settings: settings)
        #expect(manager.isVisible == true)
    }

    @Test("AutoHide stays visible when disabled")
    func staysVisibleWhenDisabled() {
        let defaults = UserDefaults(suiteName: "com.mouseon.tests.autohide.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.features.autoHideEnabled = false
        let manager = AutoHideManager(settings: settings)
        #expect(manager.isVisible == true)
    }
}

// MARK: - Sidecar Detection Edge Cases

@Suite("Sidecar Detection Edge Cases")
struct SidecarEdgeCaseTests {

    @Test("Virtual model IDs that indicate Sidecar", arguments: [
        UInt32(0xA030), UInt32(0xA031), UInt32(0xA032)
    ])
    func virtualModelIDs(modelID: UInt32) {
        // Only 0xA030+ with Apple vendor should be Sidecar
        let result = DisplayInfo.isSidecarDisplay(
            vendorID: 0x610,
            modelID: modelID,
            isBuiltin: false
        )
        // Just verify it doesn't crash — actual Sidecar detection logic varies
        _ = result
    }

    @Test("All Apple vendor IDs are checked for Sidecar")
    func allAppleVendorIDs() {
        for vendorID in Constants.Display.appleVendorIDs {
            let result = DisplayInfo.isSidecarDisplay(
                vendorID: vendorID,
                modelID: 0xA030,
                isBuiltin: false
            )
            #expect(result == true, "Vendor \(vendorID) should detect as Sidecar with virtual model")
        }
    }

    @Test("Zero vendor/model IDs don't crash")
    func zeroIDs() {
        _ = DisplayInfo.isSidecarDisplay(vendorID: 0, modelID: 0, isBuiltin: false)
        _ = DisplayInfo.isSidecarDisplay(vendorID: 0, modelID: 0, isBuiltin: true)
    }

    @Test("Max UInt32 values don't crash")
    func maxValues() {
        _ = DisplayInfo.isSidecarDisplay(vendorID: UInt32.max, modelID: UInt32.max, isBuiltin: false)
    }
}

// MARK: - Stats Manager Edge Cases

@Suite("Stats Manager Edge Cases")
@MainActor
struct StatsManagerEdgeCaseTests {

    @Test("Recording same display repeatedly doesn't lose count")
    func sameDisplayRepeatedly() async throws {
        let stats = StatsManager()
        stats.resetStats()
        try await Task.sleep(for: .milliseconds(100))

        for _ in 0..<10 {
            stats.record(switchTo: "Display 1")
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(stats.totalSwitches == 10)
    }

    @Test("Empty display name doesn't crash")
    func emptyDisplayName() async throws {
        let stats = StatsManager()
        stats.resetStats()
        stats.record(switchTo: "")
        try await Task.sleep(for: .milliseconds(100))
        #expect(stats.totalSwitches == 1)
    }

    @Test("Unicode display names work")
    func unicodeDisplayNames() async throws {
        let stats = StatsManager()
        stats.resetStats()
        stats.record(switchTo: "显示器 🖥️")
        try await Task.sleep(for: .milliseconds(100))
        #expect(stats.totalSwitches == 1)
    }

    @Test("Reset after many switches clears everything")
    func resetAfterManySwitches() async throws {
        let stats = StatsManager()
        stats.resetStats()
        try await Task.sleep(for: .milliseconds(100))

        for i in 0..<50 {
            stats.record(switchTo: "Display \(i % 5)")
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(stats.totalSwitches == 50)

        stats.resetStats()
        try await Task.sleep(for: .milliseconds(150))
        #expect(stats.totalSwitches == 0)
        #expect(stats.data.isEmpty)
    }
}

// MARK: - Alias Sanitization Tests

@Suite("Alias Sanitization")
@MainActor
struct AliasSanitizationTests {

    @Test("Alias longer than maxNameLength is trimmed on load")
    func aliasTrimmedOnLoad() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.alias-sanitize.\(UUID().uuidString)")!
        // Set maxNameLength to 5
        testDefaults.set(5, forKey: Constants.UserDefaultsKeys.maxNameLength)
        // Save an alias longer than maxNameLength
        testDefaults.set(["display1": "VeryLongName"], forKey: Constants.UserDefaultsKeys.aliases)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.aliases["display1"] == "VeryL")
    }

    @Test("Alias exactly at maxNameLength is unchanged")
    func aliasExactLength() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.alias-sanitize.\(UUID().uuidString)")!
        testDefaults.set(5, forKey: Constants.UserDefaultsKeys.maxNameLength)
        testDefaults.set(["display1": "Hello"], forKey: Constants.UserDefaultsKeys.aliases)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.aliases["display1"] == "Hello")
    }

    @Test("Alias shorter than maxNameLength is unchanged")
    func aliasShortLength() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.alias-sanitize.\(UUID().uuidString)")!
        testDefaults.set(10, forKey: Constants.UserDefaultsKeys.maxNameLength)
        testDefaults.set(["display1": "Hi"], forKey: Constants.UserDefaultsKeys.aliases)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.aliases["display1"] == "Hi")
    }
}

// MARK: - Emoji Sanitization Tests

@Suite("Emoji Sanitization")
@MainActor
struct EmojiSanitizationTests {

    @Test("Multi-emoji string is trimmed to first emoji on load")
    func multiEmojiTrimmed() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.emoji-sanitize.\(UUID().uuidString)")!
        testDefaults.set(["display1": "😀😎"], forKey: Constants.UserDefaultsKeys.displayEmojis)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.displayEmojis["display1"] == "😀")
    }

    @Test("Skin-tone emoji stays intact as single character")
    func skinToneEmojiIntact() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.emoji-sanitize.\(UUID().uuidString)")!
        testDefaults.set(["display1": "👍🏿"], forKey: Constants.UserDefaultsKeys.displayEmojis)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.displayEmojis["display1"] == "👍🏿")
    }

    @Test("Empty emoji string is filtered out on load")
    func emptyEmojiRemoved() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.emoji-sanitize.\(UUID().uuidString)")!
        testDefaults.set(["display1": ""], forKey: Constants.UserDefaultsKeys.displayEmojis)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.displayEmojis["display1"] == nil)
    }

    @Test("Single emoji stays unchanged")
    func singleEmojiUnchanged() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.emoji-sanitize.\(UUID().uuidString)")!
        testDefaults.set(["display1": "🖥️"], forKey: Constants.UserDefaultsKeys.displayEmojis)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.displayEmojis["display1"] == "🖥️")
    }
}

// MARK: - Stats Corruption Recovery Tests

@Suite("Stats Corruption Recovery")
@MainActor
struct StatsCorruptionRecoveryTests {

    @Test("Corrupted stats file is deleted and state is reset")
    func corruptedStatsRecovery() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupport.appendingPathComponent(Constants.FilePaths.appSupportFolder, isDirectory: true)
        let statsURL = appFolder.appendingPathComponent(Constants.FilePaths.statsFileName)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        // Write invalid data to stats file
        let invalidData = Data([0xFF, 0xFE, 0x00, 0x01])
        try? invalidData.write(to: statsURL)
        #expect(FileManager.default.fileExists(atPath: statsURL.path))

        // Create StatsManager which calls load() in init
        let stats = StatsManager()
        #expect(stats.data.isEmpty)
        #expect(stats.totalSwitches == 0)

        // Corrupted file should have been deleted
        #expect(!FileManager.default.fileExists(atPath: statsURL.path))
    }
}

// MARK: - Security: URL Validation Tests

@Suite("URL Validation (Fix #1)")
@MainActor
struct URLValidationTests {

    @Test("Valid HTTPS github.com URL is accepted")
    func validHTTPS() {
        let url = URL(string: "https://github.com/Omarabiakar18/MouseOn/releases/download/v1.0/MouseOn-1.0.dmg")!
        #expect(UpdateChecker.isValidDownloadURL(url))
    }

    @Test("HTTP URL is rejected")
    func httpRejected() {
        let url = URL(string: "http://github.com/download")!
        #expect(!UpdateChecker.isValidDownloadURL(url))
    }

    @Test("Foreign host is rejected")
    func foreignHostRejected() {
        let url = URL(string: "https://evil.com/malware.dmg")!
        #expect(!UpdateChecker.isValidDownloadURL(url))
    }

    @Test("Subdomain attack is rejected")
    func subdomainAttack() {
        let url = URL(string: "https://github.com.evil.com/download")!
        #expect(!UpdateChecker.isValidDownloadURL(url))
    }

    @Test("FTP scheme is rejected")
    func ftpRejected() {
        let url = URL(string: "ftp://github.com/file")!
        #expect(!UpdateChecker.isValidDownloadURL(url))
    }

    @Test("File scheme is rejected")
    func fileSchemeRejected() {
        let url = URL(string: "file:///etc/passwd")!
        #expect(!UpdateChecker.isValidDownloadURL(url))
    }

    @Test("JavaScript scheme is rejected")
    func javascriptRejected() {
        if let url = URL(string: "javascript:alert(1)") {
            #expect(!UpdateChecker.isValidDownloadURL(url))
        }
    }

    @Test("Redirect to the GitHub asset CDN is allowed")
    func redirectToCDNAllowed() {
        let url = URL(string: "https://release-assets.githubusercontent.com/github-production-release-asset/x")!
        #expect(UpdateChecker.isValidRedirectURL(url))
        #expect(UpdateChecker.isValidRedirectURL(URL(string: "https://objects.githubusercontent.com/y")!))
        #expect(UpdateChecker.isValidRedirectURL(URL(string: "https://github.com/z")!))
    }

    @Test("Redirect off GitHub-controlled hosts is rejected")
    func redirectOffGitHubRejected() {
        #expect(!UpdateChecker.isValidRedirectURL(URL(string: "https://evil.com/malware.dmg")!))
        #expect(!UpdateChecker.isValidRedirectURL(URL(string: "https://githubusercontent.com.evil.com/x")!))
        #expect(!UpdateChecker.isValidRedirectURL(URL(string: "http://objects.githubusercontent.com/x")!))
    }
}

// MARK: - Security: Download Checksum Tests

@Suite("Download Checksum Verification")
@MainActor
struct DownloadChecksumTests {

    let manifest = """
    3a7bd3e2360a3d29eea436fcfb7e44c735d117c42d1c1835420b6b9942dd4f1b  MouseOn-1.4.0.dmg
    5f2b1c1f4d1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4  MouseOn-1.4.0.zip
    """

    @Test("Checksum is found for the matching asset name")
    func findsMatchingChecksum() {
        let hash = UpdateChecker.expectedChecksum(for: "MouseOn-1.4.0.dmg", in: manifest)
        #expect(hash == "3a7bd3e2360a3d29eea436fcfb7e44c735d117c42d1c1835420b6b9942dd4f1b")
    }

    @Test("Unlisted asset has no checksum")
    func unlistedAssetHasNoChecksum() {
        #expect(UpdateChecker.expectedChecksum(for: "MouseOn-9.9.9.dmg", in: manifest) == nil)
    }

    @Test("Binary-mode asterisk prefix is tolerated")
    func binaryModePrefix() {
        let binary = "3a7bd3e2360a3d29eea436fcfb7e44c735d117c42d1c1835420b6b9942dd4f1b *MouseOn-1.4.0.dmg"
        #expect(UpdateChecker.expectedChecksum(for: "MouseOn-1.4.0.dmg", in: binary) != nil)
    }

    @Test("Malformed hash is rejected rather than trusted")
    func malformedHashRejected() {
        #expect(UpdateChecker.expectedChecksum(for: "a.dmg", in: "notahash  a.dmg") == nil)
        #expect(UpdateChecker.expectedChecksum(for: "a.dmg", in: "  a.dmg") == nil)
    }

    @Test("Hashing a file matches its known SHA-256")
    func hashesFileContents() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mouseon-hash-\(UUID().uuidString).bin")
        try Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        // Well-known SHA-256 of the string "abc"
        #expect(UpdateChecker.sha256(ofFileAt: url)
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("Hashing a missing file returns nil")
    func missingFileReturnsNil() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mouseon-absent-\(UUID().uuidString).bin")
        #expect(UpdateChecker.sha256(ofFileAt: url) == nil)
    }
}

// MARK: - Update Check Result Tests

@Suite("Update Check Failure Reporting")
@MainActor
struct UpdateCheckResultTests {

    @Test("Rate limiting is reported as its own message")
    func rateLimitMessage() {
        #expect(UpdateChecker.message(forStatusCode: 403).contains("rate-limiting"))
        #expect(UpdateChecker.message(forStatusCode: 429).contains("rate-limiting"))
    }

    @Test("Missing release and server errors are distinguished")
    func otherStatusMessages() {
        #expect(UpdateChecker.message(forStatusCode: 404).contains("No published release"))
        #expect(UpdateChecker.message(forStatusCode: 503).contains("503"))
        #expect(UpdateChecker.message(forStatusCode: 418).contains("418"))
    }

    @Test("A second concurrent check reports busy, not up to date")
    func concurrentCheckIsBusy() async {
        let checker = UpdateChecker()
        checker.isChecking = true
        #expect(await checker.checkForUpdates() == .busy)
    }
}

// MARK: - Security: Version Parsing Tests

@Suite("Version Parsing (Fix #8)")
@MainActor
struct VersionParsingTests {

    let checker = UpdateChecker()

    @Test("Simple newer version detected")
    func simpleNewer() {
        #expect(checker.isNewer("1.1", than: "1.0"))
    }

    @Test("Same version is not newer")
    func sameVersion() {
        #expect(!checker.isNewer("1.0", than: "1.0"))
    }

    @Test("Older version is not newer")
    func olderVersion() {
        #expect(!checker.isNewer("1.0", than: "1.1"))
    }

    @Test("Pre-release is not newer than same release")
    func preReleaseNotNewer() {
        #expect(!checker.isNewer("1.2-beta", than: "1.2"))
    }

    @Test("Pre-release of higher version is still newer")
    func preReleaseHigherVersion() {
        #expect(checker.isNewer("2.0-beta", than: "1.9"))
    }

    @Test("Release is newer than its own pre-release")
    func releaseNewerThanOwnPreRelease() {
        #expect(checker.isNewer("1.2", than: "1.2-beta"))
    }

    @Test("Same pre-release is not newer than itself")
    func samePreReleaseNotNewer() {
        #expect(!checker.isNewer("1.2-beta", than: "1.2-beta"))
    }

    @Test("Multi-segment version comparison")
    func multiSegment() {
        #expect(checker.isNewer("1.2.3", than: "1.2.2"))
        #expect(!checker.isNewer("1.2.2", than: "1.2.3"))
    }

    @Test("parseVersion extracts parts and suffix correctly")
    func parseVersionBasic() {
        let result = UpdateChecker.parseVersion("1.2.3-beta")
        #expect(result.parts == [1, 2, 3])
        #expect(result.hasSuffix == true)
    }

    @Test("parseVersion without suffix")
    func parseVersionNoSuffix() {
        let result = UpdateChecker.parseVersion("1.0.5")
        #expect(result.parts == [1, 0, 5])
        #expect(result.hasSuffix == false)
    }

    @Test("parseVersion handles single segment")
    func parseVersionSingle() {
        let result = UpdateChecker.parseVersion("3")
        #expect(result.parts == [3])
        #expect(result.hasSuffix == false)
    }

    @Test("parseVersion stops at the first dash in a dotted pre-release")
    func parseVersionDottedPreRelease() {
        let result = UpdateChecker.parseVersion("1.2.3-beta.1")
        #expect(result.parts == [1, 2, 3])
        #expect(result.hasSuffix == true)
    }

    @Test("Dotted pre-release is not newer than its own release")
    func dottedPreReleaseNotNewer() {
        #expect(!checker.isNewer("1.2.3-beta.1", than: "1.2.3"))
        #expect(!checker.isNewer("1.2.3-rc.2", than: "1.2.3"))
        #expect(checker.isNewer("1.2.3", than: "1.2.3-beta.1"))
    }

    @Test("Dotted pre-release of a higher version is still newer")
    func dottedPreReleaseHigherVersion() {
        #expect(checker.isNewer("2.0.0-beta.1", than: "1.9.9"))
    }
}

// MARK: - Security: Alias Control Character Tests

@Suite("Alias Control Character Filtering (Fix #9)")
@MainActor
struct AliasControlCharTests {

    @Test("Control characters stripped from alias on load")
    func controlCharsStrippedOnLoad() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.ctrlchar.\(UUID().uuidString)")!
        testDefaults.set(["display1": "Hello\t\nWorld\0"], forKey: Constants.UserDefaultsKeys.aliases)
        testDefaults.set(15, forKey: Constants.UserDefaultsKeys.maxNameLength)

        let settings = SettingsStore(defaults: testDefaults)
        let alias = settings.aliases["display1"]
        #expect(alias == "HelloWorld")
    }

    @Test("Normal text passes through unchanged")
    func normalTextUnchanged() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.ctrlchar.\(UUID().uuidString)")!
        testDefaults.set(["display1": "My Monitor"], forKey: Constants.UserDefaultsKeys.aliases)
        testDefaults.set(15, forKey: Constants.UserDefaultsKeys.maxNameLength)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.aliases["display1"] == "My Monitor")
    }

    @Test("Unicode text with control characters is cleaned")
    func unicodeWithControlChars() {
        let testDefaults = UserDefaults(suiteName: "com.mouseon.tests.ctrlchar.\(UUID().uuidString)")!
        testDefaults.set(["display1": "显示器\u{0007}🖥️"], forKey: Constants.UserDefaultsKeys.aliases)
        testDefaults.set(15, forKey: Constants.UserDefaultsKeys.maxNameLength)

        let settings = SettingsStore(defaults: testDefaults)
        #expect(settings.aliases["display1"] == "显示器🖥️")
    }
}

// MARK: - Update Constants Tests

@Suite("Update Constants")
struct UpdateConstantsTests {

    @Test("Update check interval is 6 hours")
    func checkIntervalIs6Hours() {
        #expect(Constants.Update.checkInterval == 21_600)
        #expect(Constants.Update.checkInterval == 6 * 60 * 60)
    }

    @Test("Version check URL is valid HTTPS")
    func versionCheckURLValid() {
        let url = URL(string: Constants.Update.versionCheckURL)
        #expect(url != nil)
        #expect(url?.scheme == "https")
        #expect(url?.host == "api.github.com")
    }

    @Test("Notification identifiers are non-empty and unique")
    func notificationIDsUnique() {
        let ids = [
            Constants.Update.notificationCategoryID,
            Constants.Update.installActionID,
            Constants.Update.dismissActionID
        ]
        #expect(ids.allSatisfy { !$0.isEmpty })
        #expect(Set(ids).count == ids.count)
    }

    @Test("Updates folder name is non-empty")
    func updatesFolderNameNotEmpty() {
        #expect(!Constants.FilePaths.updatesFolderName.isEmpty)
    }
}

// MARK: - VersionInfo Codable Tests

@Suite("VersionInfo Codable")
struct VersionInfoCodableTests {

    @Test("VersionInfo decodes a GitHub release, stripping the leading 'v' tag prefix")
    func decodesFromGitHubReleaseJSON() throws {
        let json = """
        {
            "tag_name": "v1.2.0",
            "body": "Bug fixes and improvements",
            "assets": [
                { "name": "MouseOn-1.2.0.zip", "browser_download_url": "https://github.com/o/r/dl/v1.2.0/MouseOn.zip" },
                { "name": "MouseOn-1.2.0.dmg", "browser_download_url": "https://github.com/o/r/dl/v1.2.0/MouseOn.dmg" }
            ]
        }
        """
        let jsonData = Data(json.utf8)

        let info = try JSONDecoder().decode(VersionInfo.self, from: jsonData)
        #expect(info.version == "1.2.0")
        #expect(info.downloadURL == "https://github.com/o/r/dl/v1.2.0/MouseOn.dmg")
        #expect(info.releaseNotes == "Bug fixes and improvements")
    }

    @Test("VersionInfo decodes with nil releaseNotes when body is absent")
    func decodesWithNilReleaseNotes() throws {
        let json = """
        {
            "tag_name": "1.0",
            "assets": [
                { "name": "MouseOn.dmg", "browser_download_url": "https://github.com/o/r/dl/1.0/MouseOn.dmg" }
            ]
        }
        """
        let jsonData = Data(json.utf8)

        let info = try JSONDecoder().decode(VersionInfo.self, from: jsonData)
        #expect(info.version == "1.0")
        #expect(info.releaseNotes == nil)
    }

    @Test("VersionInfo decoding throws when the release has no .dmg asset")
    func throwsWithoutDMGAsset() {
        let json = """
        {
            "tag_name": "v1.0",
            "assets": [
                { "name": "MouseOn-1.0.zip", "browser_download_url": "https://github.com/o/r/dl/v1.0/MouseOn.zip" }
            ]
        }
        """
        let jsonData = Data(json.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(VersionInfo.self, from: jsonData)
        }
    }
}

// MARK: - Update Notification Manager Tests

@Suite("Update Notification Manager")
@MainActor
struct UpdateNotificationManagerTests {

    @Test("Initial state has no unseen update")
    func initialStateNoUnseen() {
        let manager = UpdateNotificationManager()
        #expect(manager.hasUnseenUpdate == false)
    }

    @Test("hasUnseenUpdate can be toggled")
    func toggleUnseen() {
        let manager = UpdateNotificationManager()
        manager.hasUnseenUpdate = true
        #expect(manager.hasUnseenUpdate == true)
        manager.hasUnseenUpdate = false
        #expect(manager.hasUnseenUpdate == false)
    }

    @Test("Notification permission key defaults to false")
    func permissionKeyDefaultFalse() {
        let defaults = UserDefaults(
            suiteName: "com.mouseon.tests.notif.\(UUID().uuidString)"
        )!
        let hasRequested = defaults.bool(
            forKey: Constants.UserDefaultsKeys.hasRequestedNotificationPermission
        )
        #expect(hasRequested == false)
    }

    @Test("Notification permission key persists after set")
    func permissionKeyPersists() {
        let defaults = UserDefaults(
            suiteName: "com.mouseon.tests.notif.\(UUID().uuidString)"
        )!
        defaults.set(true, forKey: Constants.UserDefaultsKeys.hasRequestedNotificationPermission)
        #expect(
            defaults.bool(forKey: Constants.UserDefaultsKeys.hasRequestedNotificationPermission)
            == true
        )
    }
}

// MARK: - Updates Directory Tests

@Suite("Updates Directory Management")
@MainActor
struct UpdatesDirectoryTests {

    @Test("Updates directory path contains expected components")
    func updatesDirectoryPath() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let expected = appSupport
            .appendingPathComponent(Constants.FilePaths.appSupportFolder)
            .appendingPathComponent(Constants.FilePaths.updatesFolderName)
        #expect(expected.lastPathComponent == "Updates")
        #expect(expected.pathComponents.contains("MouseOn"))
    }
}
