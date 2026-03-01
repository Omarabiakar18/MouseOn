//
//  UpdateChecker.swift
//  MouseOn
//
//  Simple update checker that hits the server for version info.
//  Replaces Sparkle until we have an Apple Developer certificate.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.mouseon.app", category: "UpdateChecker")

struct VersionInfo: Codable {
    let version: String
    let downloadURL: String
    let releaseNotes: String?
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String?
    @Published var downloadURL: String?
    @Published var releaseNotes: String?
    @Published var isChecking: Bool = false

    private let versionURL = "https://mouse-on.com/api/license/version"

    /// Current app version from bundle
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    func checkForUpdates() async {
        isChecking = true
        defer { isChecking = false }

        guard let url = URL(string: versionURL) else {
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
        } catch {
            logger.error("Failed to check for updates: \(error.localizedDescription)")
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
        for i in 0..<maxLen {
            let r = i < remoteParsed.parts.count ? remoteParsed.parts[i] : 0
            let l = i < localParsed.parts.count ? localParsed.parts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }

        // Same numeric version: pre-release is NOT newer than release
        if remoteParsed.hasSuffix && !localParsed.hasSuffix {
            return false
        }

        return false
    }
}
