//
//  AccessibilityManager.swift
//  MouseOn
//
//  Manages accessibility permission checking and requests.
//  Required for NSEvent.addGlobalMonitorForEvents() to function.
//

import Foundation
import ApplicationServices
import AppKit
import Combine
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "Accessibility")

// MARK: - Accessibility Manager

/// Manages accessibility permissions required for global event monitoring
///
/// Thread Safety: This class is `@MainActor` isolated. All property access
/// and method calls are guaranteed to happen on the main thread.
/// Timer callbacks are scheduled on the main run loop.
@MainActor
final class AccessibilityManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether accessibility permissions are currently granted
    @Published private(set) var isAccessibilityEnabled: Bool = false
    
    // MARK: - Private Properties
    
    private var pollingTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        isAccessibilityEnabled = AXIsProcessTrusted()
        logger.info("Accessibility manager initialized, permission: \(self.isAccessibilityEnabled)")
    }
    
    deinit {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Checks if accessibility permissions are currently granted
    /// - Returns: True if the app has accessibility permissions
    @discardableResult
    func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        isAccessibilityEnabled = trusted
        logger.debug("Accessibility check: \(trusted ? "granted" : "denied")")
        return trusted
    }
    
    /// Requests accessibility permissions by showing the system prompt
    /// This will open System Preferences to the Privacy & Security > Accessibility pane
    func requestAccessibility() {
        logger.info("Requesting accessibility permissions")
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        isAccessibilityEnabled = trusted
        
        if trusted {
            logger.info("Accessibility permissions already granted")
        } else {
            logger.info("Accessibility prompt shown to user")
            // Start polling for permission changes
            startPollingForPermission()
        }
    }
    
    /// Opens System Preferences directly to the Accessibility pane
    func openAccessibilityPreferences() {
        logger.info("Opening accessibility preferences")
        
        // macOS 13+ uses the new URL scheme
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            logger.error("Failed to create accessibility preferences URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    /// Starts polling to detect when the user grants permission
    func startPollingForPermission() {
        stopPolling()
        
        logger.debug("Starting permission polling")
        
        // Timer runs on main run loop by default when scheduled from main thread
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if self.checkAccessibility() {
                    logger.info("Accessibility permission granted by user")
                    self.stopPolling()
                    
                    // Post notification for other parts of the app
                    NotificationCenter.default.post(
                        name: .accessibilityPermissionGranted,
                        object: nil
                    )
                }
            }
        }
    }
    
    /// Stops polling for permission changes
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let accessibilityPermissionGranted = Notification.Name("AccessibilityPermissionGranted")
}
