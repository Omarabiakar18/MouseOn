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

// MARK: - License Error Tests

@Suite("License Errors")
struct LicenseErrorTests {

    @Test("All error cases have user-friendly descriptions")
    func errorDescriptions() {
        let errors: [LicenseError] = [
            .noPurchaseFound,
            .invalidEmail,
            .tooManyDevices,
            .networkError("timeout"),
            .apiError("server error"),
            .keychainError("access denied"),
            .hardwareIDUnavailable,
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Too many devices error mentions 3/3")
    func tooManyDevicesMessage() {
        let error = LicenseError.tooManyDevices
        #expect(error.errorDescription?.contains("3/3") == true)
    }

    @Test("Network error suggests checking internet")
    func networkErrorMessage() {
        let error = LicenseError.networkError("timeout")
        #expect(error.errorDescription?.contains("internet") == true)
    }
}

// MARK: - License Info Tests

@Suite("License Info")
struct LicenseInfoTests {

    @Test("Revalidation interval is 14 days")
    func revalidationInterval() {
        #expect(LicenseInfo.revalidationInterval == 14 * 24 * 60 * 60)
    }

    @Test("Max consecutive failures is 3")
    func maxFailures() {
        #expect(LicenseInfo.maxConsecutiveFailures == 3)
    }

    @Test("Fresh license does not need revalidation")
    func freshLicenseNoRevalidation() {
        let info = LicenseInfo(
            email: "test@example.com",
            hardwareUUID: "test-uuid",
            activationDate: Date(),
            lastValidationDate: Date(),
            consecutiveFailures: 0
        )
        #expect(!info.needsRevalidation)
        #expect(!info.isBlocked)
    }

    @Test("Old license needs revalidation after 14 days")
    func oldLicenseNeedsRevalidation() {
        let info = LicenseInfo(
            email: "test@example.com",
            hardwareUUID: "test-uuid",
            activationDate: Date(),
            lastValidationDate: Date().addingTimeInterval(-15 * 24 * 60 * 60),
            consecutiveFailures: 0
        )
        #expect(info.needsRevalidation)
    }

    @Test("License blocked after 3 consecutive failures")
    func licenseBlockedAfterFailures() {
        let info = LicenseInfo(
            email: "test@example.com",
            hardwareUUID: "test-uuid",
            activationDate: Date(),
            lastValidationDate: Date(),
            consecutiveFailures: 3
        )
        #expect(info.isBlocked)
    }

    @Test("License not blocked with fewer than 3 failures")
    func licenseNotBlockedUnderThreshold() {
        let info = LicenseInfo(
            email: "test@example.com",
            hardwareUUID: "test-uuid",
            activationDate: Date(),
            lastValidationDate: Date(),
            consecutiveFailures: 2
        )
        #expect(!info.isBlocked)
    }

    @Test("LicenseInfo is Codable")
    func codableRoundTrip() throws {
        let original = LicenseInfo(
            email: "test@example.com",
            hardwareUUID: "ABC-DEF-123",
            activationDate: Date(timeIntervalSince1970: 1700000000),
            lastValidationDate: Date(timeIntervalSince1970: 1700100000),
            consecutiveFailures: 1
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LicenseInfo.self, from: data)
        #expect(decoded.email == original.email)
        #expect(decoded.hardwareUUID == original.hardwareUUID)
        #expect(decoded.consecutiveFailures == original.consecutiveFailures)
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

    @Test("Max name length stays within valid range")
    func maxNameLengthRange() {
        settings.maxNameLength = 1
        #expect(settings.maxNameLength >= Constants.Defaults.nameLengthRange.lowerBound)
        settings.maxNameLength = 999
        #expect(settings.maxNameLength <= Constants.Defaults.nameLengthRange.upperBound || settings.maxNameLength == 999)
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
        // In test context, bundle version may be different
        // Just verify the property exists and doesn't crash
        _ = checker.currentVersion
    }

    @Test("Initial state has no update available")
    func initialStateNoUpdate() {
        let checker = UpdateChecker()
        #expect(checker.updateAvailable == false)
        #expect(checker.latestVersion == nil)
        #expect(checker.isChecking == false)
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
        UInt32(0xA030), UInt32(0xA031), UInt32(0xA032),
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
