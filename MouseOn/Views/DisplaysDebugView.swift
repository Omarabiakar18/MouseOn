//
//  DisplaysDebugView.swift
//  MouseOn
//
//  Debug view showing connected displays and their properties.
//

import SwiftUI
import CoreGraphics
import Combine

// MARK: - Displays Debug View

struct DisplaysDebugView: View {
    @EnvironmentObject var tracker: DisplayTracker
    @State private var mouseLocation: NSPoint = .zero
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerSection
                mouseInfoSection

                Divider()

                displaysSection

                Divider()

                debugInfoSection

                warningsSection

                footerSection
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            tracker.refreshDisplayList()
            mouseLocation = NSEvent.mouseLocation
            // Start timer only when view appears
            timerCancellable = Timer.publish(
                every: Constants.Timing.mouseLocationUpdateInterval,
                on: .main,
                in: .common
            )
            .autoconnect()
            .sink { _ in
                mouseLocation = NSEvent.mouseLocation
            }
        }
        .onDisappear {
            // Cancel timer when view disappears to prevent leak
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Connected Displays")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Refresh") {
                tracker.refreshDisplayList()
                mouseLocation = NSEvent.mouseLocation
            }
            .accessibilityIdentifier("refreshButton")
        }
    }

    // MARK: - Mouse Info

    private var mouseInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            let currentDisplay = tracker.currentName.isEmpty ? "-" : tracker.currentName
            Text("Mouse: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y))) → \(currentDisplay)")
                .font(.caption)
                .foregroundColor(.secondary)

            if tracker.isOnUniversalControl {
                universalControlBadge
            }
        }
    }

    private var universalControlBadge: some View {
        HStack {
            Image(systemName: "ipad.and.arrow.forward")
                .foregroundColor(.blue)
            Text("Universal Control Active - Cursor on iPad")
                .font(.caption.bold())
                .foregroundColor(.blue)
        }
        .padding(6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
        .accessibilityLabel("Universal Control is active, cursor is on iPad")
    }

    // MARK: - Displays List

    private var displaysSection: some View {
        Group {
            if tracker.allDisplays.isEmpty {
                emptyDisplaysView
            } else {
                displaysList
            }
        }
    }

    private var emptyDisplaysView: some View {
        VStack(spacing: 8) {
            Text("No displays found")
                .foregroundColor(.secondary)
            Text("If your iPad is connected via Sidecar, try:")
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("• Ensure Sidecar is set to 'Extend' not 'Mirror'")
                Text("• Disconnect and reconnect the iPad")
                Text("• Move a window to the iPad screen")
                Text("• Click 'Refresh' after connecting")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var displaysList: some View {
        List(tracker.allDisplays) { display in
            DisplayInfoRow(display: display)
        }
    }

    // MARK: - Debug Info

    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Debug Info")
                .font(.caption.bold())
            Text("NSScreen.screens.count: \(NSScreen.screens.count)")
            Text("CGGetOnlineDisplayList: \(getOnlineDisplayCount()) displays")
            Text("CGGetActiveDisplayList: \(getActiveDisplayCount()) displays")
            Text("Tracker.allDisplays: \(tracker.allDisplays.count) displays")
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(.secondary)
    }

    // MARK: - Warnings

    @ViewBuilder
    private var warningsSection: some View {
        if tracker.allDisplays.contains(where: { $0.isMirrored }) {
            Divider()
            mirroringWarning
        }

        if tracker.allDisplays.count == 1 &&
           NSScreen.screens.count == 1 &&
           !tracker.allDisplays.contains(where: { $0.isMirrored }) {
            Divider()
            singleDisplayWarning
        }
    }

    private var mirroringWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🪞 MIRRORING DETECTED!")
                .foregroundColor(.red)
                .font(.caption.bold())

            Text("Your iPad is mirroring your Mac's display.")
                .font(.caption)
            Text("The mouse cannot move to a mirrored display.")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("To fix:")
                .font(.caption.bold())
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("1. Open System Settings → Displays")
                Text("2. Click on your iPad")
                Text("3. Change 'Use as' from 'Mirror...'")
                Text("   to 'Separate display'")
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: Mirroring detected. Your iPad is mirroring your Mac's display.")
    }

    private var singleDisplayWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("⚠️ Only 1 display detected")
                .foregroundColor(.orange)
                .font(.caption.bold())

            Text("If iPad is connected via Sidecar:")
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text("1. Open System Settings → Displays")
                Text("2. Click on your iPad in the display list")
                Text("3. Set 'Use as' to 'Separate display'")
                Text("   (NOT 'Mirror for...')")
                Text("4. Drag displays to arrange side-by-side")
                Text("5. Click Refresh above")
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(.top, 4)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Spacer()
            Button("Close") { NSApp.keyWindow?.close() }
                .accessibilityIdentifier("closeButton")
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func getActiveDisplayCount() -> Int {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        return Int(displayCount)
    }

    private func getOnlineDisplayCount() -> Int {
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &displayCount)
        return Int(displayCount)
    }
}

// MARK: - Display Info Row

struct DisplayInfoRow: View {
    let display: DisplayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            detailsView
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var headerRow: some View {
        HStack {
            if display.isCurrentMouse {
                Image(systemName: "cursorarrow")
                    .foregroundColor(.accentColor)
            }
            Text(display.name)
                .fontWeight(display.isCurrentMouse ? .bold : .regular)
            Spacer()
            badges
        }
    }

    @ViewBuilder
    private var badges: some View {
        if display.isMain {
            Badge(text: "Main", color: .blue)
        }
        if display.isBuiltin {
            Badge(text: "Built-in", color: .green)
        }
        if display.isSidecarGuess {
            Badge(text: "Sidecar?", color: .orange)
        }
        if display.isMirrored {
            Badge(text: "MIRRORED", color: .red)
        }
    }

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ID: \(display.id)")
            Text("Vendor: 0x\(String(display.vendorID, radix: 16, uppercase: true)) (\(display.vendorID))")
            Text("Model: 0x\(String(display.modelID, radix: 16, uppercase: true)) (\(display.modelID))")
            let origin = "\(Int(display.frame.origin.x)),\(Int(display.frame.origin.y))"
            let size = "\(Int(display.frame.width))×\(Int(display.frame.height))"
            Text("Frame: \(origin) \(size)")
            HStack(spacing: 8) {
                Text("Online: \(display.isOnline ? "✓" : "✗")")
                Text("Active: \(display.isActive ? "✓" : "✗")")
                Text("Mirrored: \(display.isMirrored ? "⚠️ YES" : "No")")
            }
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(.secondary)
    }

    private var accessibilityDescription: String {
        var parts = [display.name]
        if display.isMain { parts.append("main display") }
        if display.isBuiltin { parts.append("built-in") }
        if display.isSidecarGuess { parts.append("possibly Sidecar") }
        if display.isMirrored { parts.append("mirrored") }
        if display.isCurrentMouse { parts.append("cursor is here") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .cornerRadius(4)
    }
}

// MARK: - Preview

#if DEBUG
struct DisplaysDebugView_Previews: PreviewProvider {
    static var previews: some View {
        DisplaysDebugView()
            .environmentObject(DisplayTracker())
    }
}
#endif
