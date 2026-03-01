//
//  Constants.swift
//  MouseOn
//
//  Application-wide constants to avoid magic numbers and strings.
//

import Foundation
import CoreGraphics

// MARK: - Constants

enum Constants {

    // MARK: - Timing

    enum Timing {
        /// Fast polling interval for Universal Control detection (100ms)
        static let fastPollingInterval: TimeInterval = 0.1

        /// Slow polling interval for Universal Control detection (1s)
        static let slowPollingInterval: TimeInterval = 1.0

        /// Display list refresh interval (2s)
        static let displayRefreshInterval: TimeInterval = 2.0

        /// Mouse location update interval for debug view (500ms)
        static let mouseLocationUpdateInterval: TimeInterval = 0.5

        /// Cursor highlight animation frame interval (~60fps)
        static let highlightAnimationInterval: TimeInterval = 0.016

        /// Cursor highlight auto-dismiss duration (2s)
        static let highlightDismissDelay: TimeInterval = 2.0
    }

    // MARK: - Display Detection

    enum Display {
        /// Threshold in pixels for edge detection
        static let edgeThreshold: CGFloat = 5

        /// Apple vendor IDs for Sidecar detection
        static let appleVendorIDs: Set<UInt32> = [0x610, 1552]

        /// Model ID threshold for virtual displays
        static let virtualModelThreshold: UInt32 = 0xA000

        /// Number of stuck checks before Universal Control triggers (fast mode)
        static let fastModeStuckThreshold: Int = 3

        /// Number of stuck checks before Universal Control triggers (slow mode)
        static let slowModeStuckThreshold: Int = 2

        /// Maximum displays to query from CoreGraphics
        static let maxDisplayCount: Int = 16
    }

    // MARK: - Settings Defaults

    enum Defaults {
        /// Default menu bar item opacity
        static let opacity: Double = 0.75

        /// Opacity range bounds
        static let opacityRange: ClosedRange<Double> = 0.30...1.0

        /// Default auto-hide timeout in seconds
        static let autoHideSeconds: Int = 30

        /// Auto-hide range bounds
        static let autoHideRange: ClosedRange<Int> = 5...300

        /// Default max display name length
        static let maxNameLength: Int = 15

        /// Name length range bounds
        static let nameLengthRange: ClosedRange<Int> = 5...30

        /// Default accent color (system blue)
        static let accentColor: String = "#007AFF"

        /// Default cursor highlight color (system orange)
        static let highlightColor: String = "#FF9500"

        /// Default name for Universal Control device
        static let universalControlName: String = "iPad"

        /// Default large cursor duration in seconds
        static let largeCursorDuration: Double = 5.0

        /// Large cursor duration range
        static let largeCursorDurationRange: ClosedRange<Double> = 2.0...15.0

        /// Default large cursor size multiplier
        static let largeCursorSize: Double = 3.0

        /// Large cursor size range
        static let largeCursorSizeRange: ClosedRange<Double> = 2.0...5.0
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let features = "features"
        static let opacity = "opacity"
        static let autoHideSeconds = "autoHideSeconds"
        static let aliases = "aliases"
        static let maxNameLength = "maxNameLength"
        static let displayColors = "displayColors"
        static let useSingleAccentColor = "useSingleAccentColor"
        static let singleAccentColor = "singleAccentColor"
        static let highlightColor = "highlightColor"
        static let findCursorHotkeyEnabled = "findCursorHotkeyEnabled"
        static let displayEmojis = "displayEmojis"
        static let largeCursorDuration = "largeCursorDuration"
        static let largeCursorSize = "largeCursorSize"
    }

    // MARK: - Special Keys

    enum SpecialKeys {
        /// Key for Universal Control display in aliases/colors
        static let universalControl = "universal-control"
    }

    // MARK: - UI Constants

    enum UserInterface {
        /// Cursor highlight window size
        static let highlightWindowSize: CGFloat = 200

        /// Number of animated circles in highlight
        static let highlightCircleCount: Int = 3

        /// Highlight center dot radius
        static let highlightCenterDotRadius: CGFloat = 8

        /// Highlight circle line width
        static let highlightLineWidth: CGFloat = 3.0
    }

    // MARK: - Keychain

    enum Keychain {
        /// Service name for the encryption secret stored in macOS Keychain
        static let service = "com.mouseon.app.encryption"
        /// Account name for the encryption secret
        static let account = "license-key-secret"
    }

    // MARK: - File Paths

    enum FilePaths {
        /// App Support folder name
        static let appSupportFolder = "MouseOn"

        /// Stats file name
        static let statsFileName = "stats.json"
    }
}
