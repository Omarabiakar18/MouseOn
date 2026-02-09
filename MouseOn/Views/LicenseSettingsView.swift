//
//  LicenseSettingsView.swift
//  MouseOn
//
//  License management section for the Settings window.
//  Shows license status, activated devices, and deactivation option.
//

import SwiftUI
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "LicenseSettingsView")

// MARK: - License Settings View

/// Settings section showing license status and device management.
///
/// Displays:
/// - Licensed email address
/// - Activated devices count (e.g., "2/3")
/// - License status indicator (valid, needs revalidation, blocked)
/// - Deactivate button (instantly frees the device slot)
struct LicenseSettingsView: View {

    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var showDeactivateConfirmation = false
    @State private var isDeactivating = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("License") {
                if let info = licenseManager.licenseInfo {
                    // Licensed email
                    LabeledContent("Email") {
                        Text(info.email)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    // Device usage
                    if let usage = licenseManager.deviceUsage {
                        LabeledContent("Activated devices") {
                            Text("\(usage.activatedDevices)/\(usage.maxDevices)")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }

                    // License status
                    LabeledContent("Status") {
                        licenseStatusBadge(info: info)
                    }

                    // Activation date
                    LabeledContent("Activated") {
                        Text(info.activationDate, style: .date)
                            .foregroundColor(.secondary)
                    }

                    // Last validated
                    LabeledContent("Last validated") {
                        Text(info.lastValidationDate, style: .relative)
                            .foregroundColor(.secondary)
                    }

                    // Error message
                    if let errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    // Deactivate button
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            showDeactivateConfirmation = true
                        } label: {
                            HStack(spacing: 6) {
                                if isDeactivating {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("Deactivate This Device")
                            }
                        }
                        .disabled(isDeactivating)
                        .accessibilityIdentifier("deactivateButton")
                    }
                } else {
                    // Not licensed
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.orange)
                        Text("No active license")
                            .foregroundColor(.secondary)
                    }

                    Text("Launch the app to activate your license.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Deactivate License",
            isPresented: $showDeactivateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Deactivate", role: .destructive) {
                deactivateLicense()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will deactivate MouseOn on this device and free up an activation slot. You can reactivate later.")
        }
        .task {
            // Refresh device usage when view appears
            await licenseManager.refreshDeviceUsage()
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private func licenseStatusBadge(info: LicenseInfo) -> some View {
        if info.isBlocked {
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Blocked — please reconnect to the internet")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } else if info.needsRevalidation {
            HStack(spacing: 4) {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                Text("Revalidation pending")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - Actions

    private func deactivateLicense() {
        isDeactivating = true
        errorMessage = nil

        Task {
            do {
                try await licenseManager.deactivate()
                logger.info("Device deactivated from settings")
            } catch {
                errorMessage = error.localizedDescription
                logger.error("Deactivation failed: \(error.localizedDescription)")
            }
            isDeactivating = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LicenseSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseSettingsView()
            .frame(width: 450, height: 350)
            .previewDisplayName("License Settings")
    }
}
#endif
