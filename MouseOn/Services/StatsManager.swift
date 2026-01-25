//
//  StatsManager.swift
//  MouseOn
//
//  Manages display usage statistics tracking and persistence.
//

import Foundation
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "StatsManager")

// MARK: - Stats Manager

/// Tracks time spent on each display and switch counts
///
/// Thread Safety: This class is `@MainActor` isolated for @Published properties.
/// Queue-based operations are marked `nonisolated` and use internal synchronization.
@MainActor
final class StatsManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var data: [String: TimeInterval] = [:]
    @Published private(set) var totalSwitches: Int = 0
    
    // MARK: - Private Properties
    // These properties are protected by the serial queue for thread safety.
    // Marked nonisolated(unsafe) because the queue provides synchronization.
    
    nonisolated(unsafe) private var currentName: String?
    nonisolated(unsafe) private var startTime = Date()
    private let statsURL: URL
    private let queue = DispatchQueue(label: "com.mouseon.StatsManager")
    
    // MARK: - Initialization
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupport.appendingPathComponent(Constants.FilePaths.appSupportFolder, isDirectory: true)
        
        // Ensure app folder exists
        do {
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            logger.debug("App support directory ready: \(appFolder.path)")
        } catch {
            logger.error("Failed to create app support directory: \(error.localizedDescription)")
        }
        
        statsURL = appFolder.appendingPathComponent(Constants.FilePaths.statsFileName)
        load()
    }
    
    // MARK: - Public Methods
    
    /// Record a display switch
    /// - Parameter name: The name of the display switched to
    nonisolated func record(switchTo name: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let elapsed = Date().timeIntervalSince(self.startTime)
            if let cur = self.currentName {
                self.internalData[cur, default: 0] += elapsed
            }
            self.currentName = name
            self.startTime = Date()
            self.internalSwitches += 1
            
            let newData = self.internalData
            let newSwitches = self.internalSwitches
            
            Task { @MainActor [weak self] in
                self?.data = newData
                self?.totalSwitches = newSwitches
            }
            
            self.saveInternal()
            
            logger.debug("Recorded switch to '\(name)', total switches: \(newSwitches)")
        }
    }
    
    /// Flush current session time (call before app terminates)
    nonisolated func flush() {
        queue.sync { [weak self] in
            guard let self = self, let cur = self.currentName else { return }
            
            let elapsed = Date().timeIntervalSince(self.startTime)
            self.internalData[cur, default: 0] += elapsed
            self.startTime = Date()
            
            let newData = self.internalData
            
            // Use sync Task for flush since we need data to be saved before return
            Task { @MainActor [weak self] in
                self?.data = newData
            }
            
            self.saveInternal()
            
            logger.info("Flushed stats for '\(cur)' with \(elapsed)s elapsed")
        }
    }
    
    /// Reset all statistics
    nonisolated func resetStats() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.internalData = [:]
            self.internalSwitches = 0
            
            Task { @MainActor [weak self] in
                self?.data = [:]
                self?.totalSwitches = 0
            }
            
            self.saveInternal()
            
            logger.info("Stats reset")
        }
    }
    
    // MARK: - Private Properties (Internal State)
    // These properties are protected by the serial queue for thread safety.
    // Marked nonisolated(unsafe) because the queue provides synchronization.
    
    /// Internal data storage - access only from queue
    nonisolated(unsafe) private var internalData: [String: TimeInterval] = [:]
    /// Internal switch counter - access only from queue
    nonisolated(unsafe) private var internalSwitches: Int = 0
    
    // MARK: - Private Methods
    
    private func load() {
        guard FileManager.default.fileExists(atPath: statsURL.path) else {
            logger.debug("No existing stats file found")
            return
        }
        
        do {
            let fileData = try Data(contentsOf: statsURL)
            let loadedData = try JSONDecoder().decode([String: TimeInterval].self, from: fileData)
            internalData = loadedData
            data = loadedData
            logger.info("Loaded stats with \(loadedData.count) displays tracked")
        } catch {
            logger.error("Failed to load stats: \(error.localizedDescription)")
        }
    }
    
    /// Internal save method - must be called from queue
    nonisolated private func saveInternal() {
        do {
            let encodedData = try JSONEncoder().encode(internalData)
            try encodedData.write(to: statsURL, options: .atomic)
            logger.debug("Stats saved to disk")
        } catch {
            logger.error("Failed to save stats: \(error.localizedDescription)")
        }
    }
}
