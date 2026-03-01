//
//  SparkleManager.swift
//  MouseOn
//
//  Created by Jarvis on 2026-02-10.
//

import Foundation
#if canImport(Sparkle)
import Sparkle

/// Manages Sparkle OTA updates.
/// Requires Apple Developer ID code signing to function.
/// Until then, this is a no-op placeholder that's ready to activate.
final class SparkleManager: ObservableObject {
    
    static let shared = SparkleManager()
    
    private let updaterController: SPUStandardUpdaterController
    
    /// Whether automatic update checks are enabled
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }
    
    /// Whether the updater can check for updates right now
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
    
    private init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
    }
    
    /// Manually trigger an update check
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#else
import os.log

private let sparkleLogger = Logger(subsystem: "com.mouseon.app", category: "SparkleManager")

/// Stub when Sparkle is not available (e.g., building without the package)
final class SparkleManager: ObservableObject {
    static let shared = SparkleManager()
    @Published var automaticallyChecksForUpdates: Bool = false
    var canCheckForUpdates: Bool { false }
    func checkForUpdates() {
        sparkleLogger.info("Sparkle not available — skipping update check")
    }
}
#endif
