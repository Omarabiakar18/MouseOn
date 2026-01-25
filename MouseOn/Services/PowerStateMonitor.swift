//
//  PowerStateMonitor.swift
//  MouseOn
//
//  Monitors system power state to enable battery-aware optimizations.
//

import Foundation
import IOKit.ps
import Combine
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "PowerState")

// MARK: - Power State Monitor

/// Monitors the system's power source to enable battery-saving features
///
/// Thread Safety: This class is `@MainActor` isolated for @Published properties.
/// The IOKit callback runs on an arbitrary thread and uses `nonisolated` methods.
@MainActor
final class PowerStateMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    /// True when running on battery, false when on AC power
    @Published private(set) var isOnBattery: Bool = false
    
    /// Current battery level (0-100) or nil if not available
    @Published private(set) var batteryLevel: Int?
    
    /// Whether low power mode should be active (battery < 20%)
    @Published private(set) var isLowPowerMode: Bool = false
    
    // MARK: - Private Properties
    
    /// Run loop source - accessed from nonisolated init/deinit
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?
    /// Callback context - accessed from nonisolated init/deinit
    nonisolated(unsafe) private var callbackContext: Unmanaged<CallbackContext>?
    
    /// Helper class to safely handle callbacks with a weak reference to the monitor.
    /// This prevents crashes if the callback fires during or after deallocation.
    private final class CallbackContext {
        weak var monitor: PowerStateMonitor?
        
        init(monitor: PowerStateMonitor) {
            self.monitor = monitor
        }
    }
    
    // MARK: - Initialization
    
    nonisolated init() {
        setupPowerMonitoring()
        updatePowerState()
    }
    
    deinit {
        // IMPORTANT: Remove the run loop source FIRST to prevent any new callbacks from being scheduled
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        
        // Now release the callback context - any in-flight callbacks will see nil monitor
        // due to the weak reference in CallbackContext
        callbackContext?.release()
        callbackContext = nil
    }
    
    // MARK: - Public Methods
    
    /// Force refresh of power state
    nonisolated func refresh() {
        updatePowerState()
    }
    
    // MARK: - Private Methods
    
    nonisolated private func setupPowerMonitoring() {
        // Create a retained context with a weak reference to self.
        // This avoids the crash risk of passUnretained while still allowing safe cleanup.
        let context = CallbackContext(monitor: self)
        callbackContext = Unmanaged.passRetained(context)
        
        runLoopSource = IOPSNotificationCreateRunLoopSource({ contextPtr in
            guard let contextPtr = contextPtr else { return }
            // Use takeUnretainedValue since we manage the retain count ourselves
            let context = Unmanaged<CallbackContext>.fromOpaque(contextPtr).takeUnretainedValue()
            // Safely access monitor through weak reference - will be nil if deallocated
            context.monitor?.updatePowerState()
        }, callbackContext?.toOpaque()).takeRetainedValue()
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            logger.debug("Power monitoring setup complete")
        } else {
            logger.warning("Failed to setup power monitoring")
        }
    }
    
    nonisolated private func updatePowerState() {
        // Read power state - this can happen on any thread from the IOKit callback
        guard let powerInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSources = IOPSCopyPowerSourcesList(powerInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            logger.debug("No power source information available")
            // Dispatch @Published updates to main thread
            Task { @MainActor [weak self] in
                self?.isOnBattery = false
                self?.batteryLevel = nil
                self?.isLowPowerMode = false
            }
            return
        }
        
        // Collect new values before dispatching to main thread
        var newIsOnBattery = false
        var newBatteryLevel: Int?
        var newIsLowPowerMode = false
        
        for source in powerSources {
            guard let description = IOPSGetPowerSourceDescription(powerInfo, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // Check power source type
            if let powerSourceState = description[kIOPSPowerSourceStateKey] as? String {
                newIsOnBattery = (powerSourceState == kIOPSBatteryPowerValue)
            }
            
            // Get battery level
            if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int {
                newBatteryLevel = currentCapacity
                newIsLowPowerMode = currentCapacity < 20
            }
        }
        
        // Dispatch all @Published property updates to main thread for thread safety
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            let wasOnBattery = self.isOnBattery
            self.isOnBattery = newIsOnBattery
            
            if wasOnBattery != newIsOnBattery {
                logger.info("Power source changed: \(newIsOnBattery ? "Battery" : "AC Power")")
            }
            
            self.batteryLevel = newBatteryLevel
            self.isLowPowerMode = newIsLowPowerMode
            
            if newIsLowPowerMode, let level = newBatteryLevel {
                logger.debug("Low power mode active: \(level)%")
            }
        }
    }
}
