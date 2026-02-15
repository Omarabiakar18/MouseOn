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
            let (data, response) = try await URLSession.shared.data(from: url)

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
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Compare semantic versions (e.g. "1.1" > "1.0")
    private func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}
