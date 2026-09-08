//
//  AboutView.swift
//  MouseOn
//
//  About window showing app information and credits.
//

import SwiftUI

// MARK: - About View

struct AboutView: View {

    // MARK: - Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var copyrightYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // App Icon
            appIconSection

            // App Name and Version
            appInfoSection

            Divider()
                .padding(.horizontal, 40)

            // Description
            descriptionSection

            Divider()
                .padding(.horizontal, 40)

            // Links
            linksSection

            Spacer()

            // Copyright
            copyrightSection
        }
        .padding(24)
        .frame(width: 320, height: 380)
    }

    // MARK: - Sections

    private var appIconSection: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: 80, height: 80)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .accessibilityLabel("MouseOn app icon")
    }

    private var appInfoSection: some View {
        VStack(spacing: 4) {
            Text("MouseOn")
                .font(.title.bold())

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var descriptionSection: some View {
        VStack(spacing: 8) {
            Text("A menu bar utility that shows which display your mouse pointer is on.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            featuresRow
        }
    }

    private var featuresRow: some View {
        HStack(spacing: 16) {
            FeatureBadge(icon: "display.2", label: "Multi-Display")
            FeatureBadge(icon: "ipad", label: "Sidecar")
            FeatureBadge(icon: "cursorarrow.rays", label: "Find Cursor")
        }
        .padding(.top, 8)
    }

    private var linksSection: some View {
        VStack(spacing: 8) {
            if let websiteURL = URL(string: "https://mouse-on.com") {
                Link(destination: websiteURL) {
                    Label("mouse-on.com", systemImage: "globe")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
    }

    private var copyrightSection: some View {
        Text("© \(copyrightYear) MouseOn. All rights reserved.")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

}

// MARK: - Feature Badge

struct FeatureBadge: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Preview

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
#endif
