//
//  StatsView.swift
//  MouseOn
//
//  Display usage statistics view showing time spent on each display.
//

import SwiftUI

// MARK: - Stats View

/// Shows pointer time statistics per display
///
/// Displays a sorted list of all displays the user has used,
/// ranked by total time spent. Supports resetting all statistics.
///
/// ## Features
/// - Time breakdown per display (hours, minutes, seconds)
/// - Total switch count
/// - Reset functionality with confirmation
struct StatsView: View {
    @EnvironmentObject var stats: StatsManager
    @EnvironmentObject var settings: SettingsStore
    @State private var showResetConfirm = false

    /// Pre-computed stats data to avoid O(n²) complexity
    /// Computed once per body evaluation instead of once per row
    private var computedStats: ComputedStatsData {
        ComputedStatsData(data: stats.data) { displayID in
            settings.displayName(for: displayID)
        }
    }

    var body: some View {
        let cached = computedStats  // Compute once for this body evaluation

        VStack(spacing: 0) {
            // Header
            headerSection(totalTime: cached.totalTime)
                .padding()

            Divider()

            // Content
            if stats.data.isEmpty {
                emptyStateView
            } else {
                statsListView(entries: cached.sortedEntries)
            }

            Divider()

            // Footer
            footerView
                .padding()
        }
        .frame(minWidth: 400, minHeight: 250)
        .alert("Reset Statistics?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset All Data", role: .destructive) { stats.resetStats() }
        } message: {
            Text(
                "This will permanently delete all tracked display time and switch counts. " +
                "This action cannot be undone."
            )
        }
    }

    // MARK: - Subviews

    private func headerSection(totalTime: TimeInterval) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pointer Time per Display")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if !stats.data.isEmpty {
                    Text("Total: \(formatTime(totalTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !stats.data.isEmpty {
                Text("\(stats.totalSwitches) switches")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No data yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Move your mouse between displays to start tracking")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private func statsListView(entries: [StatsEntry]) -> some View {
        List {
            ForEach(entries) { entry in
                StatsRow(
                    displayName: entry.name,
                    seconds: entry.seconds,
                    percentage: entry.percentage
                )
            }
        }
        .listStyle(.inset)
        .accessibilityIdentifier("statsList")
    }

    private var footerView: some View {
        HStack {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset", systemImage: "trash")
            }
            .accessibilityIdentifier("resetButton")

            Spacer()

            Button("Close") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("closeButton")
        }
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600)) / 60
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

// MARK: - Computed Stats Data

/// Pre-computed statistics data for efficient rendering
/// This struct computes all values once, avoiding O(n²) complexity
/// from recalculating totalTime for each row's percentage
private struct ComputedStatsData {
    let totalTime: TimeInterval
    let sortedEntries: [StatsEntry]

    init(data: [String: TimeInterval], nameResolver: (String) -> String) {
        // Compute total time once
        let total = data.values.reduce(0, +)
        self.totalTime = total

        // Sort once and compute percentages in a single pass
        // Resolve display IDs to user-friendly names
        self.sortedEntries = data
            .sorted { $0.value > $1.value }
            .map { displayID, seconds in
                let percentage = total > 0 ? (seconds / total) * 100 : 0
                let displayName = nameResolver(displayID)
                return StatsEntry(id: displayID, name: displayName, seconds: seconds, percentage: percentage)
            }
    }
}

/// A single stats entry with pre-computed percentage
struct StatsEntry: Identifiable {
    let id: String
    let name: String
    let seconds: TimeInterval
    let percentage: Double
}

// MARK: - Stats Row

/// A single row in the statistics list
struct StatsRow: View {
    let displayName: String
    let seconds: TimeInterval
    let percentage: Double

    var body: some View {
        HStack(spacing: 12) {
            // Display name
            Text(displayName)
                .lineLimit(1)

            Spacer()

            // Percentage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: geometry.size.width)

                    Rectangle()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: geometry.size.width * CGFloat(percentage / 100))
                }
                .cornerRadius(2)
            }
            .frame(width: 60, height: 8)

            // Percentage text
            Text(String(format: "%.0f%%", percentage))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)

            // Time
            Text(formatTime(seconds))
                .font(.callout)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName): \(formatTimeAccessible(seconds)), \(Int(percentage)) percent")
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600)) / 60
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func formatTimeAccessible(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600)) / 60
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return "\(hours) hours \(minutes) minutes"
        } else if minutes > 0 {
            return "\(minutes) minutes \(secs) seconds"
        } else {
            return "\(secs) seconds"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With data
            StatsView()
                .environmentObject(makePreviewStats())
                .environmentObject(makePreviewSettings())
                .previewDisplayName("With Data")

            // Empty state
            StatsView()
                .environmentObject(StatsManager())
                .environmentObject(makePreviewSettings())
                .previewDisplayName("Empty")
        }
    }

    static func makePreviewSettings() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: "preview") ?? .standard)
    }

    static func makePreviewStats() -> StatsManager {
        let stats = StatsManager()
        // We can't easily mock the data since it's private(set)
        // In a real scenario, we'd use a protocol and mock
        return stats
    }
}
#endif
