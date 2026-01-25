//
//  AppDependencies.swift
//  MouseOn
//
//  Dependency injection container for the application.
//  Provides centralized creation and management of all services.
//

import Foundation
import AppKit
import Combine
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "Dependencies")

// MARK: - App Dependencies Protocol

/// Protocol defining the app's dependency container interface
@MainActor
protocol AppDependenciesProtocol {
    var settings: SettingsStore { get }
    var stats: StatsManager { get }
    var tracker: DisplayTracker { get }
    var launchAtLogin: LaunchAtLoginManager { get }
    var powerMonitor: PowerStateMonitor { get }
    var accessibilityManager: AccessibilityManager { get }
}

// MARK: - App Dependencies

/// Concrete implementation of the dependency container
/// Creates and wires up all services with proper dependency injection
///
/// Thread Safety: This class is `@MainActor` isolated along with all services.
/// SwiftUI's @StateObject ensures main thread creation.
@MainActor
final class AppDependencies: ObservableObject, AppDependenciesProtocol {
    
    // MARK: - Services
    
    let settings: SettingsStore
    let stats: StatsManager
    let tracker: DisplayTracker
    let launchAtLogin: LaunchAtLoginManager
    let powerMonitor: PowerStateMonitor
    let accessibilityManager: AccessibilityManager
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    private var terminationObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    init(
        settings: SettingsStore? = nil,
        stats: StatsManager? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        logger.info("Initializing app dependencies")
        
        // Create settings first (no dependencies)
        self.settings = settings ?? SettingsStore(defaults: userDefaults)
        
        // Create stats (no dependencies)
        self.stats = stats ?? StatsManager()
        
        // Create power monitor
        self.powerMonitor = PowerStateMonitor()
        
        // Create tracker with dependencies
        self.tracker = DisplayTracker()
        
        // Create launch at login manager
        self.launchAtLogin = LaunchAtLoginManager()
        
        // Create accessibility manager
        self.accessibilityManager = AccessibilityManager()
        
        // Wire up dependencies
        setupBindings()
        
        // Check accessibility permissions on startup
        checkAccessibilityPermissions()
        
        // Register for app termination to flush stats
        setupTerminationHandler()
        
        logger.info("App dependencies initialized successfully")
    }
    
    deinit {
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Inject dependencies into tracker
        tracker.inject(settings: settings, stats: stats, powerMonitor: powerMonitor)
        
        // Setup hotkey manager with settings
        HotkeyManager.shared.setup(settings: settings)
        
        // Monitor power state changes
        powerMonitor.$isOnBattery
            .removeDuplicates()
            .sink { [weak self] isOnBattery in
                logger.debug("Power state changed: \(isOnBattery ? "battery" : "AC power")")
                self?.tracker.updatePollingMode(conservePower: isOnBattery)
            }
            .store(in: &cancellables)
    }
    
    private func checkAccessibilityPermissions() {
        if !accessibilityManager.isAccessibilityEnabled {
            logger.warning("Accessibility permissions not granted. Global event monitoring will not work.")
            logger.warning("The app requires accessibility permissions for NSEvent.addGlobalMonitorForEvents()")
        } else {
            logger.info("Accessibility permissions verified")
        }
    }
    
    private func setupTerminationHandler() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            logger.info("App terminating, flushing stats")
            self?.stats.flush()
        }
    }
}

// MARK: - Preview Dependencies

#if DEBUG
/// Mock dependencies for SwiftUI previews
@MainActor
final class PreviewDependencies: AppDependenciesProtocol {
    let settings = SettingsStore(defaults: UserDefaults(suiteName: "preview")!)
    let stats = StatsManager()
    let tracker = DisplayTracker()
    let launchAtLogin = LaunchAtLoginManager()
    let powerMonitor = PowerStateMonitor()
    let accessibilityManager = AccessibilityManager()
    
    init() {
        // Setup some preview data
        settings.aliases["1"] = "MacBook Pro"
        settings.aliases["2"] = "Studio Display"
        settings.displayColors["1"] = "#007AFF"
        settings.displayColors["2"] = "#FF9500"
    }
}
#endif
