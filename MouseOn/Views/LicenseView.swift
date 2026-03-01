//
//  LicenseView.swift
//  MouseOn
//
//  First-launch activation screen. Prompts user for their activation code
//  and activates the license.
//

import SwiftUI
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "LicenseView")

// MARK: - License View

/// Shown on first launch (or when license is invalid/blocked).
/// User enters their activation code → validates → activates → dismisses.
struct LicenseView: View {

    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var activationCode: String = ""
    @State private var errorMessage: String?
    @State private var isActivating: Bool = false
    @State private var showSuccess: Bool = false

    /// Called when activation succeeds and the view should dismiss
    var onActivated: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            // App icon and title
            headerSection

            // Activation code input
            inputSection

            // Error message
            if let errorMessage {
                errorSection(errorMessage)
            }

            // Success state
            if showSuccess {
                successSection
            }

            // Activate button
            activateButton

            // Help text
            footerSection
        }
        .padding(40)
        .frame(width: 420, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cursorarrow.rays")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Activate MouseOn")
                .font(.title.bold())

            Text("Enter the activation code from your purchase to activate this device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Activation Code")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("MOUSE-XXXXXX", text: $activationCode)
                .textFieldStyle(.roundedBorder)
                .disabled(isActivating || showSuccess)
                .font(.system(.body, design: .monospaced))
                .textCase(.uppercase)
                .onSubmit { activateLicense() }
                .onChange(of: activationCode) { _, newValue in
                    activationCode = newValue.uppercased()
                }
                .accessibilityLabel("Activation code")
                .accessibilityIdentifier("licenseTokenField")
        }
    }

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.callout)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    private var successSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("License activated successfully!")
                .font(.callout)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }

    private var activateButton: some View {
        Button(action: activateLicense) {
            HStack(spacing: 8) {
                if isActivating {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(showSuccess ? "Done" : (isActivating ? "Activating..." : "Activate"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(activationCode.isEmpty || isActivating)
        .accessibilityIdentifier("activateButton")
    }

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("You can activate up to 3 devices with one purchase.")
                .font(.caption)
                .foregroundColor(.secondary)

            if let recoverURL = URL(string: "https://mouse-on.com/recover") {
                Link("Lost your code? Recover it here", destination: recoverURL)
                    .font(.caption)
            }

            if let mailURL = URL(string: "mailto:support@mouse-on.com") {
                Link("Need help? Contact support", destination: mailURL)
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func activateLicense() {
        if showSuccess {
            onActivated?()
            return
        }

        errorMessage = nil
        isActivating = true

        Task {
            do {
                try await licenseManager.activate(token: activationCode)
                showSuccess = true

                // Auto-dismiss after a short delay
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onActivated?()
            } catch {
                errorMessage = error.localizedDescription
                logger.error("Activation failed: \(error.localizedDescription)")
            }
            isActivating = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LicenseView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseView()
            .previewDisplayName("License Activation")
    }
}
#endif
