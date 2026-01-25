//
//  LaunchAtLoginManager.swift
//  MouseOn
//
//  Manages Launch at Login functionality using SMAppService.
//

import Foundation
import AppKit
import ServiceManagement
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "LaunchAtLogin")

// MARK: - Launch At Login Manager

/// Manages the app's Launch at Login state using SMAppService (macOS 13+)
///
/// Thread Safety: This class is `@MainActor` isolated. All property access
/// and method calls are guaranteed to happen on the main thread.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isEnabled: Bool = false {
        didSet {
            // Prevent reentrancy: only update if not currently updating
            // and the value actually changed
            if oldValue != isEnabled && !isUpdating {
                updateLaunchAtLoginState()
            }
        }
    }
    
    @Published private(set) var statusMessage: String = ""
    
    // MARK: - Private Properties
    
    private let service = SMAppService.mainApp
    /// Flag to prevent reentrancy when updating state
    private var isUpdating: Bool = false
    
    // MARK: - Initialization
    
    init() {
        refreshStatus()
    }
    
    // MARK: - Public Methods
    
    /// Refresh the current Launch at Login status from the system
    func refreshStatus() {
        let status = service.status
        
        // Set flag to prevent didSet from triggering updateLaunchAtLoginState
        isUpdating = true
        defer { isUpdating = false }
        
        switch status {
        case .enabled:
            isEnabled = true
            statusMessage = "Enabled"
            logger.debug("Launch at Login is enabled")
            
        case .notRegistered:
            isEnabled = false
            statusMessage = "Not enabled"
            logger.debug("Launch at Login is not registered")
            
        case .requiresApproval:
            isEnabled = false
            statusMessage = "Requires approval in System Settings"
            logger.warning("Launch at Login requires user approval")
            
        case .notFound:
            isEnabled = false
            statusMessage = "Service not found"
            logger.error("Launch at Login service not found")
            
        @unknown default:
            isEnabled = false
            statusMessage = "Unknown status"
            logger.warning("Launch at Login has unknown status: \(String(describing: status))")
        }
    }
    
    /// Open System Settings to the Login Items page
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateLaunchAtLoginState() {
        do {
            if isEnabled {
                try service.register()
                logger.info("Successfully registered for Launch at Login")
                statusMessage = "Enabled"
            } else {
                try service.unregister()
                logger.info("Successfully unregistered from Launch at Login")
                statusMessage = "Not enabled"
            }
        } catch {
            logger.error("Failed to update Launch at Login: \(error.localizedDescription)")
            statusMessage = "Error: \(error.localizedDescription)"
            
            // Revert the state since the operation failed
            // refreshStatus() will set isUpdating flag to prevent reentrancy
            refreshStatus()
        }
    }
}
