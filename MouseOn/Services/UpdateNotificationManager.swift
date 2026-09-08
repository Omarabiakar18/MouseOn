//
//  UpdateNotificationManager.swift
//  MouseOn
//
//  Manages macOS native notifications for update availability.
//  Handles permission requests, notification delivery, and user actions.
//

import Foundation
import UserNotifications
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "UpdateNotification")

// MARK: - Update Notification Manager

@MainActor
final class UpdateNotificationManager: NSObject, ObservableObject {
    static let shared = UpdateNotificationManager()

    // MARK: - Published State

    /// True when an update has been downloaded but the user hasn't acted on it
    @Published var hasUnseenUpdate: Bool = false

    // MARK: - Private

    private let center = UNUserNotificationCenter.current()

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Setup

    /// Request notification permissions and register action categories.
    /// Called once during app startup.
    func setup() {
        // Set delegate for handling notification actions
        center.delegate = self

        // Register notification category with actions
        let installAction = UNNotificationAction(
            identifier: Constants.Update.installActionID,
            title: "Install Update",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: Constants.Update.dismissActionID,
            title: "Later",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Constants.Update.notificationCategoryID,
            actions: [installAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])

        // Request permission if not already done
        let defaults = UserDefaults.standard
        let hasRequested = defaults.bool(
            forKey: Constants.UserDefaultsKeys.hasRequestedNotificationPermission
        )

        if !hasRequested {
            requestPermission()
            defaults.set(true, forKey: Constants.UserDefaultsKeys.hasRequestedNotificationPermission)
        }
    }

    // MARK: - Permission

    private func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                logger.error("Notification permission error: \(error.localizedDescription)")
            } else {
                logger.info("Notification permission \(granted ? "granted" : "denied")")
            }
        }
    }

    // MARK: - Send Notification

    /// Send a macOS notification that an update is ready to install.
    /// Authorization is queried fresh each time so permission changes made in
    /// System Settings after launch are respected.
    func sendUpdateNotification(version: String) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            logger.info("Notifications not authorized, setting badge only")
            hasUnseenUpdate = true
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "MouseOn Update Available"
        content.body = "Version \(version) is ready to install. Click to update."
        content.sound = .default
        content.categoryIdentifier = Constants.Update.notificationCategoryID

        let request = UNNotificationRequest(
            identifier: "mouseon-update-\(version)",
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await center.add(request)
            hasUnseenUpdate = true
            logger.info("Update notification sent for version \(version)")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
            hasUnseenUpdate = true
        }
    }

    // MARK: - Handle Action

    /// Handle the user clicking the notification or choosing an action
    fileprivate func handleNotificationAction(actionIdentifier: String) {
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier, Constants.Update.installActionID:
            // User clicked the notification or chose "Install Update"
            hasUnseenUpdate = false
            UpdateChecker.shared.openDownloadedDMG()
            logger.info("User initiated update install from notification")

        case Constants.Update.dismissActionID:
            // User chose "Later" — keep the badge
            logger.info("User dismissed update notification")

        default:
            break
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension UpdateNotificationManager: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    /// Handle user action on notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        Task { @MainActor [weak self] in
            self?.handleNotificationAction(actionIdentifier: actionIdentifier)
        }
        completionHandler()
    }
}
