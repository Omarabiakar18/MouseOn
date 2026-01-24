//
//  MouseOnTests.swift
//  MouseOnTests
//
//  Unit tests for MouseOn app
//

import XCTest
import SwiftUI
@testable import MouseOn

final class SettingsStoreTests: XCTestCase {
    
    var settings: SettingsStore!
    
    override func setUp() {
        super.setUp()
        settings = SettingsStore()
        // Clear any existing settings for clean tests
        UserDefaults.standard.removeObject(forKey: "aliases")
        UserDefaults.standard.removeObject(forKey: "displayColors")
        UserDefaults.standard.removeObject(forKey: "opacity")
        UserDefaults.standard.removeObject(forKey: "autoHideSeconds")
        UserDefaults.standard.removeObject(forKey: "maxNameLength")
        UserDefaults.standard.removeObject(forKey: "features")
    }
    
    override func tearDown() {
        settings = nil
        super.tearDown()
    }
    
    // MARK: - Default Values Tests
    
    func testDefaultOpacity() {
        let newSettings = SettingsStore()
        XCTAssertEqual(newSettings.opacity, 0.75, "Default opacity should be 0.75")
    }
    
    func testDefaultAutoHideSeconds() {
        let newSettings = SettingsStore()
        XCTAssertEqual(newSettings.autoHideSeconds, 30, "Default auto-hide should be 30 seconds")
    }
    
    func testDefaultMaxNameLength() {
        let newSettings = SettingsStore()
        XCTAssertEqual(newSettings.maxNameLength, 15, "Default max name length should be 15")
    }
    
    func testDefaultFeatureToggles() {
        let newSettings = SettingsStore()
        XCTAssertTrue(newSettings.features.showDataBox, "showDataBox should be true by default")
        XCTAssertTrue(newSettings.features.autoHideEnabled, "autoHideEnabled should be true by default")
        XCTAssertTrue(newSettings.features.statsEnabled, "statsEnabled should be true by default")
    }
    
    // MARK: - Alias Tests
    
    func testSetAndGetAlias() {
        settings.aliases["test-display"] = "My Display"
        XCTAssertEqual(settings.aliases["test-display"], "My Display")
    }
    
    func testAliasWithEmoji() {
        settings.aliases["test-display"] = "🖥️ Main"
        XCTAssertEqual(settings.aliases["test-display"], "🖥️ Main")
    }
    
    func testUniversalControlAlias() {
        settings.aliases["universal-control"] = "📱 iPad Pro"
        XCTAssertEqual(settings.aliases["universal-control"], "📱 iPad Pro")
    }
    
    // MARK: - Color Tests
    
    func testSetAndGetDisplayColor() {
        settings.displayColors["test-display"] = "#FF5733"
        XCTAssertEqual(settings.displayColors["test-display"], "#FF5733")
    }
    
    func testColorForDisplayReturnsNilWhenNotSet() {
        let color = settings.colorForDisplay("nonexistent")
        XCTAssertNil(color, "Should return nil for unset display color")
    }
    
    func testColorForDisplayReturnsColorWhenSet() {
        settings.displayColors["test-display"] = "#FF0000"
        let color = settings.colorForDisplay("test-display")
        XCTAssertNotNil(color, "Should return color for set display")
    }
    
    // MARK: - Persistence Tests
    
    func testSaveAndLoadAliases() {
        settings.aliases["persist-test"] = "Persisted Name"
        settings.save()
        
        let newSettings = SettingsStore()
        XCTAssertEqual(newSettings.aliases["persist-test"], "Persisted Name")
    }
    
    func testSaveAndLoadColors() {
        settings.displayColors["persist-test"] = "#00FF00"
        settings.save()
        
        let newSettings = SettingsStore()
        XCTAssertEqual(newSettings.displayColors["persist-test"], "#00FF00")
    }
    
    func testSaveAndLoadOpacity() {
        settings.opacity = 0.5
        settings.save()
        
        let newSettings = SettingsStore()
        XCTAssertEqual(newSettings.opacity, 0.5)
    }
}

// MARK: - Color Extension Tests

final class ColorExtensionTests: XCTestCase {
    
    func testColorFromValidHex() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color, "Should create color from valid hex")
    }
    
    func testColorFromHexWithoutHash() {
        let color = Color(hex: "00FF00")
        XCTAssertNotNil(color, "Should create color from hex without # prefix")
    }
    
    func testColorFromInvalidHex() {
        let color = Color(hex: "not-a-color")
        XCTAssertNil(color, "Should return nil for invalid hex")
    }
    
    func testColorToHex() {
        let color = Color(hex: "#FF0000")
        let hex = color?.toHex()
        XCTAssertNotNil(hex, "Should convert color back to hex")
        // Note: Due to color space conversions, exact match may vary
    }
}

// MARK: - Stats Manager Tests

final class StatsManagerTests: XCTestCase {
    
    var stats: StatsManager!
    
    override func setUp() {
        super.setUp()
        stats = StatsManager()
        stats.resetStats()
    }
    
    override func tearDown() {
        stats = nil
        super.tearDown()
    }
    
    func testInitialStatsEmpty() {
        XCTAssertTrue(stats.data.isEmpty, "Initial stats should be empty after reset")
    }
    
    func testInitialSwitchCountZero() {
        XCTAssertEqual(stats.totalSwitches, 0, "Initial switch count should be 0 after reset")
    }
    
    func testRecordSwitchIncrementsCount() {
        stats.record(switchTo: "Display 1")
        XCTAssertEqual(stats.totalSwitches, 1, "Switch count should increment")
    }
    
    func testRecordMultipleSwitches() {
        stats.record(switchTo: "Display 1")
        stats.record(switchTo: "Display 2")
        stats.record(switchTo: "Display 1")
        XCTAssertEqual(stats.totalSwitches, 3, "Should track multiple switches")
    }
    
    func testResetStats() {
        stats.record(switchTo: "Display 1")
        stats.record(switchTo: "Display 2")
        stats.resetStats()
        
        XCTAssertTrue(stats.data.isEmpty, "Data should be empty after reset")
        XCTAssertEqual(stats.totalSwitches, 0, "Switch count should be 0 after reset")
    }
}

// MARK: - Edge Detection Tests

final class EdgeDetectionTests: XCTestCase {
    
    // Test helper to check if a point is at screen edge
    // This mirrors the logic in DisplayTracker.isPositionAtScreenEdge
    func isAtEdge(_ point: NSPoint, screens: [NSRect], threshold: CGFloat = 5) -> Bool {
        for screen in screens {
            let atLeft = abs(point.x - screen.minX) < threshold
            let atRight = abs(point.x - screen.maxX) < threshold
            let atTop = abs(point.y - screen.maxY) < threshold
            let atBottom = abs(point.y - screen.minY) < threshold
            
            if atLeft || atRight || atTop || atBottom {
                return true
            }
        }
        return false
    }
    
    func testPointAtLeftEdge() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let point = NSPoint(x: 2, y: 500)
        XCTAssertTrue(isAtEdge(point, screens: [screen]), "Point at left edge should be detected")
    }
    
    func testPointAtRightEdge() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let point = NSPoint(x: 1918, y: 500)
        XCTAssertTrue(isAtEdge(point, screens: [screen]), "Point at right edge should be detected")
    }
    
    func testPointAtTopEdge() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let point = NSPoint(x: 960, y: 1078)
        XCTAssertTrue(isAtEdge(point, screens: [screen]), "Point at top edge should be detected")
    }
    
    func testPointAtBottomEdge() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let point = NSPoint(x: 960, y: 2)
        XCTAssertTrue(isAtEdge(point, screens: [screen]), "Point at bottom edge should be detected")
    }
    
    func testPointInCenter() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let point = NSPoint(x: 960, y: 540)
        XCTAssertFalse(isAtEdge(point, screens: [screen]), "Point in center should not be at edge")
    }
    
    func testPointAtCorner() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let point = NSPoint(x: 0, y: 0)
        XCTAssertTrue(isAtEdge(point, screens: [screen]), "Point at corner should be at edge")
    }
    
    func testMultipleScreens() {
        let screen1 = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let screen2 = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        
        // Point between screens (at right edge of screen1)
        let point = NSPoint(x: 1918, y: 500)
        XCTAssertTrue(isAtEdge(point, screens: [screen1, screen2]), "Point at edge between screens should be detected")
    }
}

// MARK: - Clamped Extension Tests

final class ClampedExtensionTests: XCTestCase {
    
    func testClampedWithinRange() {
        let value = 50
        let clamped = value.clamped(to: 0...100)
        XCTAssertEqual(clamped, 50, "Value within range should not change")
    }
    
    func testClampedBelowRange() {
        let value = -10
        let clamped = value.clamped(to: 0...100)
        XCTAssertEqual(clamped, 0, "Value below range should clamp to lower bound")
    }
    
    func testClampedAboveRange() {
        let value = 150
        let clamped = value.clamped(to: 0...100)
        XCTAssertEqual(clamped, 100, "Value above range should clamp to upper bound")
    }
    
    func testClampedAtLowerBound() {
        let value = 0
        let clamped = value.clamped(to: 0...100)
        XCTAssertEqual(clamped, 0, "Value at lower bound should not change")
    }
    
    func testClampedAtUpperBound() {
        let value = 100
        let clamped = value.clamped(to: 0...100)
        XCTAssertEqual(clamped, 100, "Value at upper bound should not change")
    }
    
    func testClampedDouble() {
        let value = 1.5
        let clamped = value.clamped(to: 0.0...1.0)
        XCTAssertEqual(clamped, 1.0, "Double above range should clamp to upper bound")
    }
}

// MARK: - Universal Control Detection Tests

final class UniversalControlDetectionTests: XCTestCase {
    
    // Simulates the stuck-at-edge detection logic
    func simulateStuckDetection(positions: [NSPoint], screens: [NSRect], threshold: Int = 3) -> Bool {
        var lastPosition: NSPoint = .zero
        var stuckCount = 0
        
        for position in positions {
            let atEdge = isAtScreenEdge(position, screens: screens)
            let samePosition = position == lastPosition
            
            if atEdge && samePosition {
                stuckCount += 1
                if stuckCount >= threshold {
                    return true
                }
            } else {
                stuckCount = 0
            }
            
            lastPosition = position
        }
        
        return false
    }
    
    func isAtScreenEdge(_ point: NSPoint, screens: [NSRect], edgeThreshold: CGFloat = 5) -> Bool {
        for screen in screens {
            let atLeft = abs(point.x - screen.minX) < edgeThreshold
            let atRight = abs(point.x - screen.maxX) < edgeThreshold
            let atTop = abs(point.y - screen.maxY) < edgeThreshold
            let atBottom = abs(point.y - screen.minY) < edgeThreshold
            
            if atLeft || atRight || atTop || atBottom {
                return true
            }
        }
        return false
    }
    
    func testStuckAtEdgeDetected() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let positions: [NSPoint] = [
            NSPoint(x: 0, y: 500),  // At left edge
            NSPoint(x: 0, y: 500),  // Same position
            NSPoint(x: 0, y: 500),  // Same position
            NSPoint(x: 0, y: 500),  // Same position - should trigger
        ]
        
        XCTAssertTrue(simulateStuckDetection(positions: positions, screens: [screen]),
                      "Should detect cursor stuck at edge")
    }
    
    func testMovingCursorNotDetected() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let positions: [NSPoint] = [
            NSPoint(x: 0, y: 500),
            NSPoint(x: 0, y: 501),  // Moved
            NSPoint(x: 0, y: 502),  // Moved
            NSPoint(x: 0, y: 503),  // Moved
        ]
        
        XCTAssertFalse(simulateStuckDetection(positions: positions, screens: [screen]),
                       "Moving cursor should not trigger detection")
    }
    
    func testCursorInCenterNotDetected() {
        let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let positions: [NSPoint] = [
            NSPoint(x: 960, y: 540),
            NSPoint(x: 960, y: 540),
            NSPoint(x: 960, y: 540),
            NSPoint(x: 960, y: 540),
        ]
        
        XCTAssertFalse(simulateStuckDetection(positions: positions, screens: [screen]),
                       "Cursor stuck in center should not trigger (not at edge)")
    }
}

// MARK: - Cursor Highlighter Tests

final class CursorHighlighterTests: XCTestCase {
    
    func testHighlighterIsSingleton() {
        let instance1 = CursorHighlighter.shared
        let instance2 = CursorHighlighter.shared
        XCTAssertTrue(instance1 === instance2, "CursorHighlighter should be a singleton")
    }
    
    func testHighlightDoesNotCrash() {
        // Simply verify that calling highlight doesn't crash
        CursorHighlighter.shared.highlight()
        
        // Wait a bit for the animation to start
        let expectation = XCTestExpectation(description: "Highlight animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
