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

// MARK: - Persisted Stats Data

/// Container for persisted statistics data
private struct PersistedStats: Codable {
    var displayTimes: [String: TimeInterval]
    var totalSwitches: Int

    init(displayTimes: [String: TimeInterval] = [:], totalSwitches: Int = 0) {
        self.displayTimes = displayTimes
        self.totalSwitches = totalSwitches
    }
}

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

    nonisolated(unsafe) private var currentDisplayID: String?
    nonisolated(unsafe) private var startTime = Date()
    nonisolated(unsafe) private var pendingSave: DispatchWorkItem?
    private let statsURL: URL
    private let queue = DispatchQueue(label: "com.mouseon.StatsManager")

    /// Debounce interval for saving stats (reduces disk I/O)
    private let saveDebounceInterval: TimeInterval = 5.0

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
    /// - Parameter displayID: The unique ID of the display switched to
    nonisolated func record(switchTo displayID: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(self.startTime)
            if let cur = self.currentDisplayID {
                self.internalData[cur, default: 0] += elapsed
            }
            self.currentDisplayID = displayID
            self.startTime = Date()
            self.internalSwitches += 1

            let newData = self.internalData
            let newSwitches = self.internalSwitches

            Task { @MainActor [weak self] in
                self?.data = newData
                self?.totalSwitches = newSwitches
            }

            // Debounced save to reduce disk I/O
            self.scheduleSave()

            logger.debug("Recorded switch to display '\(displayID)', total switches: \(newSwitches)")
        }
    }

    /// Flush current session time (call before app terminates)
    nonisolated func flush() {
        queue.sync { [weak self] in
            guard let self = self, let cur = self.currentDisplayID else { return }

            let elapsed = Date().timeIntervalSince(self.startTime)
            self.internalData[cur, default: 0] += elapsed
            self.startTime = Date()

            let newData = self.internalData

            // Use sync Task for flush since we need data to be saved before return
            Task { @MainActor [weak self] in
                self?.data = newData
            }

            self.saveInternal()

            logger.info("Flushed stats for display '\(cur)' with \(elapsed)s elapsed")
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

            // Try loading new format first
            if let persistedStats = try? JSONDecoder().decode(PersistedStats.self, from: fileData) {
                internalData = persistedStats.displayTimes
                internalSwitches = persistedStats.totalSwitches
                data = persistedStats.displayTimes
                totalSwitches = persistedStats.totalSwitches
                let count = persistedStats.displayTimes.count
                let switches = persistedStats.totalSwitches
                logger.info("Loaded stats: \(count) displays, \(switches) switches")
            } else {
                // Fall back to legacy format (just the dictionary)
                let loadedData = try JSONDecoder().decode([String: TimeInterval].self, from: fileData)
                internalData = loadedData
                data = loadedData
                logger.info("Loaded legacy stats with \(loadedData.count) displays tracked")
            }
        } catch {
            logger.error("Failed to load stats: \(error.localizedDescription)")
        }
    }

    /// Schedule a debounced save to reduce disk I/O
    nonisolated private func scheduleSave() {
        // Cancel any pending save
        pendingSave?.cancel()

        // Schedule new save after debounce interval
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveInternal()
        }
        pendingSave = workItem
        queue.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }

    /// Internal save method - must be called from queue
    nonisolated private func saveInternal() {
        // Clear pending save since we're saving now
        pendingSave?.cancel()
        pendingSave = nil

        do {
            let persistedStats = PersistedStats(
                displayTimes: internalData,
                totalSwitches: internalSwitches
            )
            let encodedData = try JSONEncoder().encode(persistedStats)
            try encodedData.write(to: statsURL, options: .atomic)
            logger.debug("Stats saved to disk (switches: \(self.internalSwitches))")
        } catch {
            logger.error("Failed to save stats: \(error.localizedDescription)")
        }
    }
}
