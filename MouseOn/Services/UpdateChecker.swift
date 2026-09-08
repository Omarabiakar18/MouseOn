//
//  UpdateChecker.swift
//  MouseOn
//
//  Background auto-update checker that periodically checks for new versions,
//  downloads the DMG silently, and notifies via macOS notifications.
//

import Foundation
import AppKit
import CryptoKit
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "UpdateChecker")

// MARK: - Version Info

/// Decodes a GitHub Releases API "latest release" response into the fields
/// the update checker needs: the release tag (as a bare version), the first
/// `.dmg` asset's name and download URL, the checksum manifest URL used to
/// verify that download, and the release notes body.
struct VersionInfo: Decodable {
    let version: String
    let downloadURL: String
    let dmgName: String
    /// URL of the release's `SHA256SUMS.txt` asset, if it publishes one.
    let checksumsURL: String?
    let releaseNotes: String?

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case assets
    }

    private enum AssetCodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let tagName = try container.decode(String.self, forKey: .tagName)
        version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        releaseNotes = try container.decodeIfPresent(String.self, forKey: .body)

        var assetsContainer = try container.nestedUnkeyedContainer(forKey: .assets)
        var dmgURL: String?
        var dmgAssetName: String?
        var sumsURL: String?
        while !assetsContainer.isAtEnd {
            let asset = try assetsContainer.nestedContainer(keyedBy: AssetCodingKeys.self)
            let name = try asset.decode(String.self, forKey: .name)
            if name.hasSuffix(".dmg"), dmgURL == nil {
                dmgURL = try asset.decode(String.self, forKey: .browserDownloadURL)
                dmgAssetName = name
            } else if name == Constants.Update.checksumsAssetName {
                sumsURL = try asset.decode(String.self, forKey: .browserDownloadURL)
            }
        }
        guard let dmgURL, let dmgAssetName else {
            throw DecodingError.dataCorruptedError(
                forKey: .assets,
                in: container,
                debugDescription: "Latest release has no .dmg asset"
            )
        }
        downloadURL = dmgURL
        dmgName = dmgAssetName
        checksumsURL = sumsURL
    }
}

// MARK: - Check Result

/// Outcome of an update check. Distinguishes "no update" from "the check
/// didn't complete", so an interactive check never claims the app is current
/// when it simply failed to reach GitHub.
enum UpdateCheckResult: Equatable {
    case updateAvailable
    case upToDate
    /// Another check was already running; this one did nothing.
    case busy
    case failed(String)
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
    /// Asset name of the DMG in the latest release, used to find its checksum
    /// line in the release's `SHA256SUMS.txt`.
    private var latestDMGName: String?
    /// URL of the latest release's checksum manifest, if it publishes one.
    private var checksumsURL: String?
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

    /// User-initiated check: opens the downloaded DMG if an update is available,
    /// otherwise reports the outcome. Shared by the app menu and Settings.
    func checkForUpdatesInteractively() async {
        switch await checkForUpdates() {
        case .updateAvailable:
            openDownloadedDMG()
        case .upToDate:
            showAlert(
                style: .informational,
                title: "You're up to date!",
                message: "MouseOn \(currentVersion) is the latest version."
            )
        case .busy:
            showAlert(
                style: .informational,
                title: "Checking for updates…",
                message: "A check is already running. Try again in a moment."
            )
        case .failed(let reason):
            showAlert(
                style: .warning,
                title: "Couldn't check for updates",
                message: "\(reason)\n\nYou can download the latest version from the releases page."
            )
        }
    }

    private func showAlert(style: NSAlert.Style, title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func performBackgroundCheck() async {
        guard await checkForUpdates() == .updateAvailable else { return }

        if let urlString = downloadURL, let url = URL(string: urlString) {
            guard Self.isValidDownloadURL(url) else {
                logger.warning("Blocked download from untrusted URL: \(urlString)")
                return
            }
            await downloadUpdate(from: url)
        }
    }

    @discardableResult
    func checkForUpdates() async -> UpdateCheckResult {
        guard !isChecking else { return .busy }
        isChecking = true
        defer { isChecking = false }

        guard let url = URL(string: Constants.Update.versionCheckURL) else {
            logger.error("Invalid version check URL")
            return .failed("The update location is misconfigured.")
        }

        do {
            let request = URLRequest(url: url, timeoutInterval: 15)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.warning("Version check got a non-HTTP response")
                return .failed("The update server returned an unexpected response.")
            }
            guard httpResponse.statusCode == 200 else {
                logger.warning("Version check returned \(httpResponse.statusCode)")
                return .failed(Self.message(forStatusCode: httpResponse.statusCode))
            }

            let info = try JSONDecoder().decode(VersionInfo.self, from: data)
            latestVersion = info.version
            downloadURL = info.downloadURL
            releaseNotes = info.releaseNotes
            latestDMGName = info.dmgName
            checksumsURL = info.checksumsURL

            updateAvailable = isNewer(info.version, than: currentVersion)

            // Record check timestamp
            UserDefaults.standard.set(Date(), forKey: Constants.UserDefaultsKeys.lastUpdateCheck)

            if updateAvailable {
                logger.info("Update available: \(info.version) (current: \(self.currentVersion))")
                return .updateAvailable
            }
            logger.info("App is up to date (\(self.currentVersion))")
            return .upToDate

        } catch is DecodingError {
            logger.error("Could not decode the latest release payload")
            return .failed("The update server returned a response MouseOn didn't understand.")
        } catch {
            logger.error("Failed to check for updates: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }

    /// Human-readable explanation for the HTTP failures GitHub actually returns.
    static func message(forStatusCode code: Int) -> String {
        switch code {
        case 403, 429:
            return "GitHub is rate-limiting update checks right now."
        case 404:
            return "No published release was found."
        case 500...599:
            return "GitHub is having trouble (server error \(code))."
        default:
            return "The update server returned an error (\(code))."
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
            try? FileManager.default.removeItem(at: location)
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
        } catch {
            logger.error("Failed to save downloaded DMG: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: location)
            return
        }

        // The DMG is neither signed nor notarized, so the published SHA-256 is
        // the only integrity control. Publish the download to the rest of the
        // app (and notify the user) only once it verifies.
        Task { [weak self] in
            await self?.verifyAndPublish(dmgAt: destURL, version: version)
        }
    }

    /// Verifies the downloaded DMG against the release's published SHA-256 before
    /// exposing it as installable. A file that fails - or a release that ships no
    /// checksum at all - is discarded, leaving `openDownloadedDMG()` to fall back
    /// to the releases page rather than opening an unverified disk image.
    private func verifyAndPublish(dmgAt url: URL, version: String) async {
        guard let expected = await fetchExpectedChecksum() else {
            logger.error("No published SHA-256 for this release - discarding download")
            try? FileManager.default.removeItem(at: url)
            return
        }

        let path = url.path
        let actual = await Task.detached(priority: .utility) {
            Self.sha256(ofFileAt: URL(fileURLWithPath: path))
        }.value

        guard let actual, actual == expected else {
            logger.error("DMG checksum mismatch - discarding download")
            try? FileManager.default.removeItem(at: url)
            return
        }

        downloadedDMGURL = url
        logger.info("DMG downloaded and verified at \(url.path)")

        await UpdateNotificationManager.shared.sendUpdateNotification(version: version)
    }

    /// Downloads the release's checksum manifest and pulls out the DMG's hash.
    private func fetchExpectedChecksum() async -> String? {
        guard let urlString = checksumsURL,
              let url = URL(string: urlString),
              Self.isValidDownloadURL(url),
              let dmgName = latestDMGName else { return nil }

        do {
            let request = URLRequest(url: url, timeoutInterval: 30)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let manifest = String(data: data, encoding: .utf8) else { return nil }
            return Self.expectedChecksum(for: dmgName, in: manifest)
        } catch {
            logger.error("Failed to fetch checksums: \(error.localizedDescription)")
            return nil
        }
    }

    /// Streams a file through SHA-256 so a large DMG is never held in memory.
    nonisolated static func sha256(ofFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: Constants.Update.hashChunkSize),
              !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Extracts one file's hash from `shasum -a 256` output
    /// (`<hex>  <filename>`, one entry per line).
    nonisolated static func expectedChecksum(for fileName: String, in manifest: String) -> String? {
        for line in manifest.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 2 else { continue }
            // Binary-mode output prefixes the name with "*".
            let name = fields[fields.count - 1].drop { $0 == "*" }
            guard name == fileName else { continue }
            let hash = fields[0].lowercased()
            let isHex = hash.count == 64 && hash.allSatisfy(\.isHexDigit)
            return isHex ? hash : nil
        }
        return nil
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
        // Fall back to the GitHub Releases page, which isn't itself a
        // download URL, so it's opened unconditionally rather than through
        // the isValidDownloadURL allowlist.
        guard let urlString = downloadURL else {
            if let releasesURL = URL(string: "https://github.com/Omarabiakar18/MouseOn/releases") {
                NSWorkspace.shared.open(releasesURL)
            }
            return
        }
        guard let url = URL(string: urlString), Self.isValidDownloadURL(url) else {
            logger.warning("Blocked opening untrusted download URL: \(urlString)")
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

    /// Validates that a download URL is trusted (HTTPS + allowed host).
    /// GitHub release asset downloads originate from github.com and redirect
    /// to a CDN host, which URLSession follows transparently.
    static func isValidDownloadURL(_ url: URL) -> Bool {
        guard url.scheme == "https" else { return false }
        let allowedHosts: Set<String> = ["github.com"]
        guard let host = url.host, allowedHosts.contains(host) else { return false }
        return true
    }

    /// Validates a hop in the download's redirect chain. `isValidDownloadURL`
    /// only vets the URL we start from; GitHub then redirects release assets to
    /// its own CDN, so every subsequent hop is checked here rather than trusted
    /// blindly. Keeps the chain inside GitHub-controlled hosts, over HTTPS.
    nonisolated static func isValidRedirectURL(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return host == "github.com"
            || host == "githubusercontent.com"
            || host.hasSuffix(".githubusercontent.com")
    }

    /// Parse a version string into numeric parts and a pre-release flag
    /// e.g. "1.2.3-beta" → (parts: [1, 2, 3], hasSuffix: true)
    ///
    /// Everything from the first `-` on is pre-release identifiers, not version
    /// numbers: "1.2.3-beta.1" must parse as [1, 2, 3] rather than [1, 2, 3, 1],
    /// or its trailing "1" reads as a fourth component that outranks the release.
    static func parseVersion(_ version: String) -> (parts: [Int], hasSuffix: Bool) {
        let dashIndex = version.firstIndex(of: "-")
        let numeric = version[version.startIndex..<(dashIndex ?? version.endIndex)]
        let parts = numeric.split(separator: ".").compactMap { Int($0) }
        return (parts, dashIndex != nil)
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

        // Same numeric version: the release build is newer than its own
        // pre-release (e.g. "1.2" is an update for "1.2-beta"), but a
        // pre-release is never newer than the release, and identical
        // suffix status means no update.
        return localParsed.hasSuffix && !remoteParsed.hasSuffix
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
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, UpdateChecker.isValidRedirectURL(url) else {
            logger.warning("Blocked update download redirect to an untrusted host")
            completionHandler(nil)
            return
        }
        completionHandler(request)
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
