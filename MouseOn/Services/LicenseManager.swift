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

// TODO: Replace with actual Paddle credentials
private let PADDLE_VENDOR_ID = "REPLACE_ME"
private let PADDLE_VENDOR_AUTH_CODE = "REPLACE_ME"

// TODO: Replace with actual Paddle endpoints when verified
private enum PaddleAPI {
    static let verifyPurchase = "https://vendors.paddle.com/api/2.0/product/verify_purchase"
    static let activateDevice = "https://vendors.paddle.com/api/2.0/product/activate_license"
    static let deactivateDevice = "https://vendors.paddle.com/api/2.0/product/deactivate_license"
    static let getLicenseInfo = "https://vendors.paddle.com/api/2.0/product/get_license_usage"
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
            return "Maximum devices reached (3/3). Deactivate another device first."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .hardwareIDUnavailable:
            return "Unable to read hardware identifier."
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
            kIOMasterPortDefault,
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

    /// Verify that a purchase exists for this email
    private func verifyPurchase(email: String) async throws {
        let url = URL(string: PaddleAPI.verifyPurchase)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "vendor_id": PADDLE_VENDOR_ID,
            "vendor_auth_code": PADDLE_VENDOR_AUTH_CODE,
            "email": email
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw LicenseError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw LicenseError.apiError("Unexpected response format")
        }

        if !success {
            let message = (json["error"] as? [String: Any])?["message"] as? String
            if message?.lowercased().contains("no purchase") == true || message?.lowercased().contains("not found") == true {
                throw LicenseError.noPurchaseFound
            }
            throw LicenseError.apiError(message ?? "Unknown error")
        }
    }

    /// Activate a device (register hardware UUID with Paddle)
    private func activateDevice(email: String, hardwareUUID: String) async throws -> DeviceUsageInfo {
        let url = URL(string: PaddleAPI.activateDevice)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "vendor_id": PADDLE_VENDOR_ID,
            "vendor_auth_code": PADDLE_VENDOR_AUTH_CODE,
            "email": email,
            "machine_id": hardwareUUID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LicenseError.networkError("Failed to activate device")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool else {
            throw LicenseError.apiError("Unexpected response format")
        }

        if !success {
            let message = (json["error"] as? [String: Any])?["message"] as? String
            if message?.lowercased().contains("limit") == true || message?.lowercased().contains("maximum") == true {
                throw LicenseError.tooManyDevices
            }
            throw LicenseError.apiError(message ?? "Activation failed")
        }

        // Parse usage info from response
        let responseData = json["response"] as? [String: Any]
        let activated = responseData?["activated"] as? Int ?? 1
        let maxDevices = responseData?["max"] as? Int ?? 3

        return DeviceUsageInfo(activatedDevices: activated, maxDevices: maxDevices)
    }

    /// Deactivate a device (unregister hardware UUID)
    private func deactivateDevice(email: String, hardwareUUID: String) async throws {
        let url = URL(string: PaddleAPI.deactivateDevice)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "vendor_id": PADDLE_VENDOR_ID,
            "vendor_auth_code": PADDLE_VENDOR_AUTH_CODE,
            "email": email,
            "machine_id": hardwareUUID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LicenseError.networkError("Failed to deactivate device")
        }
    }

    /// Fetch device usage info
    private func fetchDeviceUsage(email: String) async throws -> DeviceUsageInfo {
        let url = URL(string: PaddleAPI.getLicenseInfo)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "vendor_id": PADDLE_VENDOR_ID,
            "vendor_auth_code": PADDLE_VENDOR_AUTH_CODE,
            "email": email
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LicenseError.networkError("Failed to fetch usage info")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseData = json["response"] as? [String: Any] else {
            throw LicenseError.apiError("Unexpected response format")
        }

        let activated = responseData["activated"] as? Int ?? 0
        let maxDevices = responseData["max"] as? Int ?? 3

        return DeviceUsageInfo(activatedDevices: activated, maxDevices: maxDevices)
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
