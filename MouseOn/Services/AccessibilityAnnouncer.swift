//
//  AccessibilityAnnouncer.swift
//  MouseOn
//
//  Provides VoiceOver announcements for display changes and app events.
//

import AppKit
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "Accessibility")

// MARK: - Accessibility Announcer

/// Announces app events to VoiceOver users
@MainActor
final class AccessibilityAnnouncer {

    // MARK: - Shared Instance

    static let shared = AccessibilityAnnouncer()

    // MARK: - Private Properties

    private var lastAnnouncedDisplay: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Announce a display change to VoiceOver
    /// - Parameter displayName: The name of the new display
    func announceDisplayChange(_ displayName: String) {
        // Don't announce if same display or VoiceOver is not running
        guard displayName != lastAnnouncedDisplay else { return }
        guard NSWorkspace.shared.isVoiceOverEnabled else { return }

        lastAnnouncedDisplay = displayName

        let announcement = "Now on \(displayName)"
        announce(announcement)

        logger.debug("VoiceOver announcement: \(announcement)")
    }

    /// Announce when cursor highlight is triggered
    func announceFindCursor() {
        guard NSWorkspace.shared.isVoiceOverEnabled else { return }
        announce("Cursor highlighted")
    }

    /// Announce when large cursor mode is activated
    func announceLargeCursor() {
        guard NSWorkspace.shared.isVoiceOverEnabled else { return }
        announce("Large cursor activated")
    }

    /// Announce Universal Control state change
    /// - Parameter isOnUC: Whether cursor is now on Universal Control device
    func announceUniversalControlChange(_ isOnUC: Bool) {
        guard NSWorkspace.shared.isVoiceOverEnabled else { return }

        if isOnUC {
            announce("Cursor moved to iPad via Universal Control")
        } else {
            announce("Cursor returned from iPad")
        }
    }

    // MARK: - Private Methods

    private func announce(_ message: String) {
        // Post accessibility notification
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}
