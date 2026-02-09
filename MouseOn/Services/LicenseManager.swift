//
//  LicenseManager.swift
//  MouseOn
//
//  Core licensing logic: validates purchases via Paddle API,
//  manages device activation/deactivation, and handles offline grace periods.
//

import Foundation
import Security
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
    case keychainError(String)
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
        case .keychainError:
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

    private let keychainService = "com.mouseon.app.license"
    private let keychainAccount = "activation"
    private var revalidationTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadFromKeychain()
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

        // Step 3: Store in Keychain
        let info = LicenseInfo(
            email: trimmed,
            hardwareUUID: hardwareUUID,
            activationDate: Date(),
            lastValidationDate: Date(),
            consecutiveFailures: 0
        )
        try saveToKeychain(info)

        // Update state
        licenseInfo = info
        deviceUsage = usage
        isLicensed = true

        logger.info("License activated successfully")
    }

    /// Deactivate this device. Frees the activation slot immediately.
    func deactivate() async throws {
        guard let info = licenseInfo else { return }

        isValidating = true
        defer { isValidating = false }

        logger.info("Deactivating license for this device")

        // Call Paddle API to deactivate
        try await deactivateDevice(email: info.email, hardwareUUID: info.hardwareUUID)

        // Remove from Keychain
        deleteFromKeychain()

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
            try? saveToKeychain(info)
            licenseInfo = info
            isLicensed = true

            logger.info("Revalidation succeeded")
        } catch {
            // Failure: increment counter
            info.consecutiveFailures += 1
            try? saveToKeychain(info)
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

    // MARK: - Keychain Storage

    /// Save license info to Keychain
    private func saveToKeychain(_ info: LicenseInfo) throws {
        let data = try JSONEncoder().encode(info)

        // Delete existing item first
        deleteFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw LicenseError.keychainError("Failed to save: OSStatus \(status)")
        }

        logger.debug("License info saved to Keychain")
    }

    /// Load license info from Keychain
    private func loadFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let info = try? JSONDecoder().decode(LicenseInfo.self, from: data) else {
            logger.debug("No license found in Keychain")
            isLicensed = false
            return
        }

        licenseInfo = info

        // Licensed unless blocked by too many revalidation failures
        isLicensed = !info.isBlocked

        if info.isBlocked {
            logger.warning("License is blocked due to failed revalidations")
        } else {
            logger.info("License loaded from Keychain for \(info.email, privacy: .private)")
        }
    }

    /// Delete license info from Keychain
    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
