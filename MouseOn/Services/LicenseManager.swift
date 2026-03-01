//
//  LicenseManager.swift
//  MouseOn
//
//  Core licensing logic: validates purchases via Paddle API,
//  manages device activation/deactivation, and handles offline grace periods.
//

import Foundation
import CryptoKit
import Security  // Needed for Keychain migration
import IOKit
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "LicenseManager")

// MARK: - Paddle API Configuration

// MARK: - License API Configuration
// Points to our own licensing backend (NOT Paddle directly).
// Paddle Billing doesn't have built-in license management — we handle it ourselves.
// Our backend receives Paddle webhooks and manages license state.

// TODO: Replace with actual production URL when deployed
private enum LicenseAPI {
    static let baseURL = "https://mouse-on.com/api/license"  // TODO: Update when backend is deployed
    static let validate = "\(baseURL)/validate"
    static let activate = "\(baseURL)/activate"
    static let deactivate = "\(baseURL)/deactivate"
}

// MARK: - License Error

enum LicenseError: LocalizedError {
    case noPurchaseFound
    case invalidEmail
    case tooManyDevices
    case networkError(String)
    case apiError(String)
    case storageError(String)
    case hardwareIDUnavailable

    var errorDescription: String? {
        switch self {
        case .noPurchaseFound:
            return "No purchase found for this email address."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .tooManyDevices:
            return "Maximum devices reached (3/3). Deactivate another device in Settings first."
        case .networkError:
            return "Unable to connect. Please check your internet connection and try again."
        case .apiError(let message):
            return "Something went wrong: \(message)"
        case .storageError:
            return "Unable to save license data. Please try again."
        case .hardwareIDUnavailable:
            return "Unable to identify this Mac. Please contact support."
        }
    }
}

// MARK: - License Info

/// Cached license information stored in Keychain
struct LicenseInfo: Codable {
    let email: String
    let hardwareUUID: String
    let activationDate: Date
    var lastValidationDate: Date
    var consecutiveFailures: Int

    /// Maximum consecutive failed revalidations before blocking
    static let maxConsecutiveFailures = 3

    /// Revalidation interval (14 days)
    static let revalidationInterval: TimeInterval = 14 * 24 * 60 * 60

    /// Whether the license needs revalidation
    var needsRevalidation: Bool {
        Date().timeIntervalSince(lastValidationDate) >= Self.revalidationInterval
    }

    /// Whether the license is blocked due to too many failed revalidations
    var isBlocked: Bool {
        consecutiveFailures >= Self.maxConsecutiveFailures
    }
}

// MARK: - Device Info (from API)

struct DeviceUsageInfo {
    let activatedDevices: Int
    let maxDevices: Int
}

// MARK: - License Manager

/// Manages app licensing: activation, deactivation, validation, and offline grace.
///
/// Flow:
/// 1. On first launch → show LicenseView (enter email)
/// 2. Validate email against Paddle API
/// 3. Activate this device (register hardware UUID)
/// 4. Store activation in Keychain
/// 5. Every 14 days, silently revalidate
/// 6. If revalidation fails 3 times → block until online validation succeeds
/// 7. User can deactivate device from settings (frees slot instantly)
@MainActor
final class LicenseManager: ObservableObject {

    // MARK: - Singleton

    static let shared = LicenseManager()

    // MARK: - Published State

    @Published private(set) var isLicensed: Bool = false
    @Published private(set) var licenseInfo: LicenseInfo?
    @Published private(set) var deviceUsage: DeviceUsageInfo?
    @Published private(set) var isValidating: Bool = false

    // MARK: - Private Properties

    private var revalidationTimer: Timer?

    /// Application Support directory for persistent license storage
    private static var licenseFileURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            logger.error("Application Support directory unavailable")
            return nil
        }
        let dir = appSupport.appendingPathComponent("MouseOn", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("license.dat")
    }

    // MARK: - Initialization

    private init() {
        migrateFromKeychainIfNeeded()
        migrateEncryptionKeyIfNeeded()
        loadLicense()
        startRevalidationTimer()
    }

    // MARK: - Hardware UUID

    /// Get the Mac's hardware UUID (IOPlatformUUID)
    static func getHardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let key = kIOPlatformUUIDKey as CFString
        guard let uuid = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String else {
            return nil
        }
        return uuid
    }

    // MARK: - Public Methods

    /// Activate this device with the given purchase email.
    ///
    /// Steps:
    /// 1. Validate email format
    /// 2. Get hardware UUID
    /// 3. Verify purchase with Paddle API
    /// 4. Activate device (register UUID)
    /// 5. Store in Keychain
    func activate(email: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Validate email format
        guard isValidEmail(trimmed) else {
            throw LicenseError.invalidEmail
        }

        // Get hardware UUID
        guard let hardwareUUID = Self.getHardwareUUID() else {
            throw LicenseError.hardwareIDUnavailable
        }

        isValidating = true
        defer { isValidating = false }

        logger.info("Activating license for \(trimmed, privacy: .private)")

        // Step 1: Verify purchase exists
        try await verifyPurchase(email: trimmed)

        // Step 2: Activate this device
        let usage = try await activateDevice(email: trimmed, hardwareUUID: hardwareUUID)

        // Step 3: Store in Application Support
        let info = LicenseInfo(
            email: trimmed,
            hardwareUUID: hardwareUUID,
            activationDate: Date(),
            lastValidationDate: Date(),
            consecutiveFailures: 0
        )
        try saveLicense(info)

        // Update state
        licenseInfo = info
        deviceUsage = usage
        isLicensed = true

        logger.info("License activated successfully")
    }

    /// Activate using an activation token (e.g. MOUSE-XXXXXX) instead of email
    func activate(token: String) async throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !trimmed.isEmpty else {
            throw LicenseError.apiError("Please enter your activation code")
        }

        guard let hardwareUUID = Self.getHardwareUUID() else {
            throw LicenseError.hardwareIDUnavailable
        }

        isValidating = true
        defer { isValidating = false }

        logger.info("Activating license with token")

        // Activate directly with token — server validates and activates in one step
        let (data, httpResponse) = try await apiRequest(
            endpoint: LicenseAPI.activate,
            body: ["token": trimmed, "hardware_uuid": hardwareUUID]
        )

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw LicenseError.noPurchaseFound
            }
            if httpResponse.statusCode == 409 {
                throw LicenseError.tooManyDevices
            }
            // Try to extract error message from response
            if let apiResponse = try? APIResponse(from: data), let error = apiResponse.error {
                throw LicenseError.apiError(error)
            }
            throw LicenseError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let apiResponse = try APIResponse(from: data)

        if !apiResponse.success {
            throw LicenseError.apiError(apiResponse.error ?? "Activation failed")
        }

        // Store license info — use token as identifier since we don't have email locally
        let info = LicenseInfo(
            email: trimmed, // Store token as the identifier
            hardwareUUID: hardwareUUID,
            activationDate: Date(),
            lastValidationDate: Date(),
            consecutiveFailures: 0
        )
        try saveLicense(info)

        // Update state
        licenseInfo = info
        deviceUsage = DeviceUsageInfo(
            activatedDevices: apiResponse.activatedDevices,
            maxDevices: apiResponse.maxDevices
        )
        isLicensed = true

        logger.info("License activated successfully via token")
    }

    /// Deactivate this device. Frees the activation slot immediately.
    func deactivate() async throws {
        guard let info = licenseInfo else { return }

        isValidating = true
        defer { isValidating = false }

        logger.info("Deactivating license for this device")

        // Call Paddle API to deactivate
        try await deactivateDevice(email: info.email, hardwareUUID: info.hardwareUUID)

        // Remove license file
        deleteLicense()

        // Update state
        licenseInfo = nil
        deviceUsage = nil
        isLicensed = false

        logger.info("License deactivated successfully")
    }

    /// Silently revalidate the license. Called every 14 days.
    ///
    /// On success: resets failure counter, updates last validation date.
    /// On failure: increments failure counter. After 3 failures → blocks app.
    func revalidate() async {
        guard var info = licenseInfo else { return }

        guard info.needsRevalidation else {
            logger.debug("Revalidation not needed yet")
            return
        }

        logger.info("Performing silent revalidation")

        do {
            try await verifyPurchase(email: info.email)

            // Success: reset failures, update validation date
            info.lastValidationDate = Date()
            info.consecutiveFailures = 0
            do {
                try saveLicense(info)
            } catch {
                logger.error("Failed to save license after revalidation success: \(error.localizedDescription)")
            }
            licenseInfo = info
            isLicensed = true

            logger.info("Revalidation succeeded")
        } catch {
            // Failure: increment counter
            info.consecutiveFailures += 1
            do {
                try saveLicense(info)
            } catch {
                logger.error("Failed to save license after revalidation failure: \(error.localizedDescription)")
            }
            licenseInfo = info

            if info.isBlocked {
                isLicensed = false
                logger.warning("License blocked after \(info.consecutiveFailures) consecutive failures")
            } else {
                logger.warning("Revalidation failed (\(info.consecutiveFailures)/\(LicenseInfo.maxConsecutiveFailures))")
            }
        }
    }

    /// Fetch current device usage info from API
    func refreshDeviceUsage() async {
        guard let info = licenseInfo else { return }
        do {
            deviceUsage = try await fetchDeviceUsage(email: info.email)
        } catch {
            logger.error("Failed to refresh device usage: \(error.localizedDescription)")
        }
    }

    // MARK: - Revalidation Timer

    private func startRevalidationTimer() {
        // Check daily whether revalidation is needed
        revalidationTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.revalidate()
            }
        }
    }

    // MARK: - Email Validation

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Paddle API Calls

    // MARK: - API Response Parsing

    /// Standard response from our license backend
    private struct APIResponse {
        let success: Bool
        let error: String?
        let activatedDevices: Int
        let maxDevices: Int

        init(from data: Data) throws {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LicenseError.apiError("Invalid response format")
            }

            self.success = json["valid"] as? Bool ?? json["success"] as? Bool ?? false
            self.error = json["error"] as? String
            self.activatedDevices = json["activated_devices"] as? Int ?? 0
            self.maxDevices = json["max_devices"] as? Int ?? 3
        }
    }

    /// Make a POST request to our license backend
    private func apiRequest(endpoint: String, body: [String: Any]) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: endpoint) else {
            throw LicenseError.apiError("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError("Invalid response")
        }

        return (data, httpResponse)
    }

    /// Verify that a purchase exists for this email
    private func verifyPurchase(email: String) async throws {
        guard let hardwareUUID = Self.getHardwareUUID() else {
            throw LicenseError.hardwareIDUnavailable
        }

        let (data, httpResponse) = try await apiRequest(
            endpoint: LicenseAPI.validate,
            body: ["email": email, "hardware_uuid": hardwareUUID]
        )

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw LicenseError.noPurchaseFound
            }
            throw LicenseError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let apiResponse = try APIResponse(from: data)

        if !apiResponse.success {
            if let error = apiResponse.error, error.lowercased().contains("no purchase") {
                throw LicenseError.noPurchaseFound
            }
            throw LicenseError.apiError(apiResponse.error ?? "Validation failed")
        }
    }

    /// Activate a device (register hardware UUID with our backend)
    private func activateDevice(email: String, hardwareUUID: String) async throws -> DeviceUsageInfo {
        let (data, httpResponse) = try await apiRequest(
            endpoint: LicenseAPI.activate,
            body: ["email": email, "hardware_uuid": hardwareUUID]
        )

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 409 {
                throw LicenseError.tooManyDevices
            }
            throw LicenseError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let apiResponse = try APIResponse(from: data)

        if !apiResponse.success {
            if let error = apiResponse.error, error.lowercased().contains("limit") || error.lowercased().contains("maximum") {
                throw LicenseError.tooManyDevices
            }
            throw LicenseError.apiError(apiResponse.error ?? "Activation failed")
        }

        return DeviceUsageInfo(
            activatedDevices: apiResponse.activatedDevices,
            maxDevices: apiResponse.maxDevices
        )
    }

    /// Deactivate a device (unregister hardware UUID)
    private func deactivateDevice(email: String, hardwareUUID: String) async throws {
        let (_, httpResponse) = try await apiRequest(
            endpoint: LicenseAPI.deactivate,
            body: ["email": email, "hardware_uuid": hardwareUUID]
        )

        guard httpResponse.statusCode == 200 else {
            throw LicenseError.networkError("Failed to deactivate device")
        }
    }

    /// Fetch device usage info (uses validate endpoint)
    private func fetchDeviceUsage(email: String) async throws -> DeviceUsageInfo {
        guard let hardwareUUID = Self.getHardwareUUID() else {
            throw LicenseError.hardwareIDUnavailable
        }

        let (data, httpResponse) = try await apiRequest(
            endpoint: LicenseAPI.validate,
            body: ["email": email, "hardware_uuid": hardwareUUID]
        )

        guard httpResponse.statusCode == 200 else {
            throw LicenseError.networkError("Failed to fetch usage info")
        }

        let apiResponse = try APIResponse(from: data)
        return DeviceUsageInfo(
            activatedDevices: apiResponse.activatedDevices,
            maxDevices: apiResponse.maxDevices
        )
    }

    // MARK: - Encrypted File Storage

    /// Legacy encryption key derived solely from hardware UUID (for migration)
    private static func legacyEncryptionKey() -> SymmetricKey? {
        guard let uuid = getHardwareUUID() else { return nil }
        let hash = SHA256.hash(data: Data(uuid.utf8))
        return SymmetricKey(data: hash)
    }

    /// Read or create a random 32-byte secret in macOS Keychain
    private static func keychainSecret() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.service,
            kSecAttrAccount as String: Constants.Keychain.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        }

        // Generate and store a new random secret
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, 32, &randomBytes)
        guard randomStatus == errSecSuccess else {
            logger.error("Failed to generate random bytes: OSStatus \(randomStatus)")
            return nil
        }

        let secretData = Data(randomBytes)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.Keychain.service,
            kSecAttrAccount as String: Constants.Keychain.account,
            kSecValueData as String: secretData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            logger.error("Failed to store Keychain secret: OSStatus \(addStatus)")
            return nil
        }

        logger.info("Generated new Keychain encryption secret")
        return secretData
    }

    /// Derive a symmetric encryption key from hardware UUID + Keychain secret
    private static func encryptionKey() -> SymmetricKey? {
        guard let uuid = getHardwareUUID() else { return nil }
        guard let secret = keychainSecret() else { return nil }
        var combined = Data(uuid.utf8)
        combined.append(secret)
        let hash = SHA256.hash(data: combined)
        return SymmetricKey(data: hash)
    }

    /// Save license info to encrypted file in Application Support
    private func saveLicense(_ info: LicenseInfo) throws {
        guard let key = Self.encryptionKey() else {
            throw LicenseError.hardwareIDUnavailable
        }

        guard let fileURL = Self.licenseFileURL else {
            throw LicenseError.storageError("Application Support directory unavailable")
        }

        let data = try JSONEncoder().encode(info)
        let sealed = try AES.GCM.seal(data, using: key)

        guard let combined = sealed.combined else {
            throw LicenseError.apiError("Encryption failed")
        }

        try combined.write(to: fileURL)
        logger.debug("License info saved to Application Support")
    }

    /// Load license info from encrypted file in Application Support
    private func loadLicense() {
        guard let key = Self.encryptionKey() else {
            logger.debug("Cannot derive encryption key")
            isLicensed = false
            return
        }

        guard let fileURL = Self.licenseFileURL,
              let combined = try? Data(contentsOf: fileURL),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let data = try? AES.GCM.open(box, using: key),
              let info = try? JSONDecoder().decode(LicenseInfo.self, from: data) else {
            logger.debug("No license found in Application Support")
            isLicensed = false
            return
        }

        licenseInfo = info
        isLicensed = !info.isBlocked

        if info.isBlocked {
            logger.warning("License is blocked due to failed revalidations")
        } else {
            logger.info("License loaded for \(info.email, privacy: .private)")
        }
    }

    /// Delete license file
    private func deleteLicense() {
        guard let fileURL = Self.licenseFileURL else {
            logger.warning("Cannot delete license: Application Support directory unavailable")
            return
        }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            logger.error("Failed to delete license file: \(error.localizedDescription)")
        }
    }

    // MARK: - Encryption Key Migration

    /// Migrate license data from legacy encryption key (UUID-only) to new key (UUID + Keychain secret)
    private func migrateEncryptionKeyIfNeeded() {
        guard let fileURL = Self.licenseFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return // No license file to migrate
        }

        // If we can already decrypt with the new key, no migration needed
        if let newKey = Self.encryptionKey(),
           let combined = try? Data(contentsOf: fileURL),
           let box = try? AES.GCM.SealedBox(combined: combined),
           (try? AES.GCM.open(box, using: newKey)) != nil {
            return
        }

        // Try to decrypt with legacy key and re-encrypt with new key
        guard let legacyKey = Self.legacyEncryptionKey(),
              let combined = try? Data(contentsOf: fileURL),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let plaintext = try? AES.GCM.open(box, using: legacyKey),
              let info = try? JSONDecoder().decode(LicenseInfo.self, from: plaintext) else {
            logger.debug("No legacy-encrypted license to migrate")
            return
        }

        guard let newKey = Self.encryptionKey() else {
            logger.warning("Cannot derive new encryption key for migration")
            return
        }

        do {
            let newSealed = try AES.GCM.seal(plaintext, using: newKey)
            guard let newCombined = newSealed.combined else {
                logger.error("Encryption key migration: seal failed")
                return
            }
            try newCombined.write(to: fileURL)
            logger.info("Migrated license encryption to hardened key for \(info.email, privacy: .private)")
        } catch {
            logger.error("Encryption key migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Keychain Migration

    /// One-time migration from Keychain to Application Support (for existing users)
    private func migrateFromKeychainIfNeeded() {
        // Skip if we already have a license file
        guard let fileURL = Self.licenseFileURL else {
            logger.warning("Cannot check migration: Application Support directory unavailable")
            return
        }
        if FileManager.default.fileExists(atPath: fileURL.path) { return }

        // Try to read from old Keychain location
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.mouseon.app.license",
            kSecAttrAccount as String: "activation",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let info = try? JSONDecoder().decode(LicenseInfo.self, from: data) else {
            return // No Keychain data to migrate
        }

        // Save to new location
        do {
            try saveLicense(info)
            // Clean up old Keychain entry
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.mouseon.app.license",
                kSecAttrAccount as String: "activation"
            ]
            let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
            if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
                logger.warning("Failed to delete old Keychain entry: OSStatus \(deleteStatus)")
            }
            logger.info("Migrated license from Keychain to Application Support")
        } catch {
            logger.warning("Failed to migrate from Keychain: \(error.localizedDescription)")
        }
    }
}
