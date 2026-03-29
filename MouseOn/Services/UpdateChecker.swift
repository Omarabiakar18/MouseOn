//
//  UpdateChecker.swift
//  MouseOn
//
//  Background auto-update checker that periodically checks for new versions,
//  downloads the DMG silently, and notifies via macOS notifications.
//

import Foundation
import AppKit
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "UpdateChecker")

// MARK: - Version Info

struct VersionInfo: Codable {
    let version: String
    let downloadURL: String
    let releaseNotes: String?
}

// MARK: - Update Checker

@MainActor
final class UpdateChecker: NSObject, ObservableObject {
    static let shared = UpdateChecker()

    // MARK: - Published State

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String?
    @Published var downloadURL: String?
    @Published var releaseNotes: String?
    @Published var isChecking: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadedDMGURL: URL?

    // MARK: - Private

    private var checkTimer: Timer?
    private var downloadTask: URLSessionDownloadTask?
    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.isDiscretionary = true
        config.allowsExpensiveNetworkAccess = false
        return URLSession(configuration: config, delegate: downloadDelegate, delegateQueue: .main)
    }()
    private let downloadDelegate = DownloadDelegate()

    /// Current app version from bundle
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    // MARK: - Initialization

    override init() {
        super.init()
        downloadDelegate.checker = self
    }

    // MARK: - Background Checking

    /// Start the background update check loop. Called once from AppDependencies.
    func startBackgroundChecking() {
        logger.info("Starting background update checking (interval: 6h)")

        // Check immediately if enough time has passed since last check
        if shouldCheckNow() {
            Task {
                await performBackgroundCheck()
            }
        }

        // Schedule recurring timer
        checkTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Update.checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performBackgroundCheck()
            }
        }
    }

    /// Stop background checking (cleanup)
    func stopBackgroundChecking() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Check Logic

    private func performBackgroundCheck() async {
        await checkForUpdates()

        if updateAvailable, let urlString = downloadURL, let url = URL(string: urlString) {
            guard Self.isValidDownloadURL(url) else {
                logger.warning("Blocked download from untrusted URL: \(urlString)")
                return
            }
            await downloadUpdate(from: url)
        }
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let url = URL(string: Constants.Update.versionCheckURL) else {
            logger.error("Invalid version check URL")
            return
        }

        do {
            let request = URLRequest(url: url, timeoutInterval: 15)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.warning("Version check returned non-200")
                return
            }

            let info = try JSONDecoder().decode(VersionInfo.self, from: data)
            latestVersion = info.version
            downloadURL = info.downloadURL
            releaseNotes = info.releaseNotes

            updateAvailable = isNewer(info.version, than: currentVersion)

            if updateAvailable {
                logger.info("Update available: \(info.version) (current: \(self.currentVersion))")
            } else {
                logger.info("App is up to date (\(self.currentVersion))")
            }

            // Record check timestamp
            UserDefaults.standard.set(Date(), forKey: Constants.UserDefaultsKeys.lastUpdateCheck)

        } catch {
            logger.error("Failed to check for updates: \(error.localizedDescription)")
        }
    }

    // MARK: - Download

    private func downloadUpdate(from url: URL) async {
        // Skip if we already have this version downloaded
        if let existing = downloadedDMGURL,
           FileManager.default.fileExists(atPath: existing.path) {
            logger.info("DMG already downloaded, skipping re-download")
            return
        }

        guard !isDownloading else { return }
        isDownloading = true

        logger.info("Starting silent DMG download from \(url.absoluteString)")

        // Clean up old downloads
        cleanupOldDownloads()

        let request = URLRequest(url: url, timeoutInterval: 300)
        downloadTask = downloadSession.downloadTask(with: request)
        downloadTask?.resume()
    }

    /// Called by the download delegate when download completes
    fileprivate func handleDownloadComplete(location: URL) {
        isDownloading = false

        guard let updatesDir = updatesDirectory() else {
            logger.error("Cannot access updates directory")
            return
        }

        let version = latestVersion ?? "unknown"
        let destURL = updatesDir.appendingPathComponent("MouseOn-\(version).dmg")

        do {
            // Remove existing file at destination if any
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: location, to: destURL)
            downloadedDMGURL = destURL
            logger.info("DMG downloaded to \(destURL.path)")

            // Notify via macOS notification
            Task {
                await UpdateNotificationManager.shared.sendUpdateNotification(version: version)
            }
        } catch {
            logger.error("Failed to save downloaded DMG: \(error.localizedDescription)")
        }
    }

    /// Called by the download delegate on failure
    fileprivate func handleDownloadError(_ error: Error) {
        isDownloading = false
        logger.error("DMG download failed: \(error.localizedDescription)")
    }

    // MARK: - Install

    /// Open the downloaded DMG for user to install
    func openDownloadedDMG() {
        if let dmgURL = downloadedDMGURL, FileManager.default.fileExists(atPath: dmgURL.path) {
            NSWorkspace.shared.open(dmgURL)
            logger.info("Opened DMG for installation: \(dmgURL.path)")
        } else {
            // Fallback to download page
            openDownloadPage()
        }
    }

    func openDownloadPage() {
        guard let urlString = downloadURL ?? Optional("https://mouse-on.com/recover"),
              let url = URL(string: urlString),
              Self.isValidDownloadURL(url) else {
            logger.warning("Blocked opening untrusted download URL: \(self.downloadURL ?? "nil")")
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - File Management

    private func updatesDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        let dir = appSupport
            .appendingPathComponent(Constants.FilePaths.appSupportFolder)
            .appendingPathComponent(Constants.FilePaths.updatesFolderName)

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            logger.error("Failed to create updates directory: \(error.localizedDescription)")
            return nil
        }
    }

    private func cleanupOldDownloads() {
        guard let dir = updatesDirectory() else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            )
            for file in files where file.pathExtension == "dmg" {
                try FileManager.default.removeItem(at: file)
                logger.debug("Cleaned up old DMG: \(file.lastPathComponent)")
            }
        } catch {
            logger.warning("Failed to cleanup old downloads: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func shouldCheckNow() -> Bool {
        guard let lastCheck = UserDefaults.standard.object(
            forKey: Constants.UserDefaultsKeys.lastUpdateCheck
        ) as? Date else {
            return true // Never checked
        }
        return Date().timeIntervalSince(lastCheck) >= Constants.Update.checkInterval
    }

    /// Validates that a download URL is trusted (HTTPS + allowed host)
    static func isValidDownloadURL(_ url: URL) -> Bool {
        guard url.scheme == "https" else { return false }
        let allowedHosts: Set<String> = ["mouse-on.com", "www.mouse-on.com"]
        guard let host = url.host, allowedHosts.contains(host) else { return false }
        return true
    }

    /// Parse a version string into numeric parts and a pre-release flag
    /// e.g. "1.2.3-beta" → (parts: [1, 2, 3], hasSuffix: true)
    static func parseVersion(_ version: String) -> (parts: [Int], hasSuffix: Bool) {
        var hasSuffix = false
        let parts: [Int] = version.split(separator: ".").compactMap { segment in
            let str = String(segment)
            if let dashIndex = str.firstIndex(of: "-") {
                hasSuffix = true
                let numericPart = str[str.startIndex..<dashIndex]
                return Int(numericPart)
            }
            return Int(str)
        }
        return (parts, hasSuffix)
    }

    /// Compare semantic versions (e.g. "1.1" > "1.0")
    /// Pre-release versions (e.g. "1.2-beta") are never newer than the same numeric release
    func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParsed = Self.parseVersion(remote)
        let localParsed = Self.parseVersion(local)

        let maxLen = max(remoteParsed.parts.count, localParsed.parts.count)
        for idx in 0..<maxLen {
            let remoteVal = idx < remoteParsed.parts.count ? remoteParsed.parts[idx] : 0
            let localVal = idx < localParsed.parts.count ? localParsed.parts[idx] : 0
            if remoteVal > localVal { return true }
            if remoteVal < localVal { return false }
        }

        // Same numeric version: pre-release is NOT newer than release
        if remoteParsed.hasSuffix && !localParsed.hasSuffix {
            return false
        }

        return false
    }
}

// MARK: - Download Delegate

/// Non-isolated delegate that forwards results back to UpdateChecker on main actor
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var checker: UpdateChecker?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Copy to a temporary location before the system deletes it
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".dmg")
        do {
            try FileManager.default.copyItem(at: location, to: tempURL)
        } catch {
            Task { @MainActor [weak self] in
                self?.checker?.handleDownloadError(error)
            }
            return
        }

        Task { @MainActor [weak self] in
            self?.checker?.handleDownloadComplete(location: tempURL)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            Task { @MainActor [weak self] in
                self?.checker?.handleDownloadError(error)
            }
        }
    }
}
