//
//  DisplayTracker.swift
//  MouseOn
//
//  Tracks mouse cursor location across displays and detects Universal Control.
//  Uses Combine for reactive updates and supports battery-aware polling.
//

import AppKit
import CoreGraphics
import Combine
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "DisplayTracker")

// MARK: - Display Tracker

/// Tracks which display the mouse cursor is currently on
///
/// This class monitors mouse movement across all connected displays,
/// detects Sidecar and Universal Control devices, and publishes the
/// current display name for the menu bar.
///
/// ## Features
/// - Real-time display tracking via mouse event monitoring
/// - Sidecar (iPad as display) detection
/// - Universal Control detection (cursor stuck at screen edge)
/// - Battery-aware polling (reduces frequency when on battery)
/// - Automatic display list refresh on configuration changes
///
/// ## Thread Safety
/// This class is `@MainActor` isolated. Timer and event callbacks
/// are scheduled on the main run loop. Internal state queue operations
/// use `nonisolated` where needed.
///
/// ## Usage
/// ```swift
/// let tracker = DisplayTracker()
/// tracker.inject(settings: settings, stats: stats, powerMonitor: powerMonitor)
///
/// // Observe current display
/// tracker.$currentName.sink { name in
///     print("Mouse is on: \(name)")
/// }
/// ```
@MainActor
final class DisplayTracker: ObservableObject {

    // MARK: - Published Properties

    /// The name of the display where the mouse cursor is currently located
    @Published private(set) var currentName: String = ""

    /// The CoreGraphics display ID of the current display, if known
    @Published private(set) var currentDisplayID: CGDirectDisplayID?

    /// List of all connected displays with their properties
    @Published private(set) var allDisplays: [DisplayInfo] = []

    /// True when the cursor appears to be on a Universal Control device (iPad)
    @Published private(set) var isOnUniversalControl: Bool = false

    // MARK: - Private Properties

    /// Event monitors - accessed from nonisolated deinit
    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var localMonitor: Any?
    private weak var stats: StatsManager?
    private weak var settings: SettingsStore?
    private weak var powerMonitor: PowerStateMonitor?
    private var lastDisplayID: CGDirectDisplayID?
    private var displayObserver: Any?

    // Combine-based timers
    private var displayRefreshCancellable: AnyCancellable?
    private var universalControlCancellable: AnyCancellable?

    // Serial queue for thread-safe access to Universal Control detection state
    private let stateQueue = DispatchQueue(label: "com.mouseon.displaytracker.state")

    /// Result of Universal Control state check (avoids large tuple)
    private struct UCCheckResult {
        let shouldSwitchToFast: Bool
        let shouldSwitchToSlow: Bool
        let likelyOnUC: Bool
        let wasOnUC: Bool
    }

    // Universal Control detection state (access synchronized via stateQueue)
    private var lastMousePosition: NSPoint = .zero
    private var stuckAtEdgeCount: Int = 0
    private var isInFastPollingMode: Bool = false
    private var isConservingPower: Bool = false
    /// Internal synchronized state for Universal Control - used for thread-safe logic checks
    /// The @Published isOnUniversalControl is only updated on main thread
    private var isOnUniversalControlInternal: Bool = false

    // MARK: - Deinitialization

    deinit {
        removeMonitors()
        displayRefreshCancellable?.cancel()
        universalControlCancellable?.cancel()
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        logger.debug("DisplayTracker deinitialized")
    }

    // MARK: - Public Methods

    /// Initialize the tracker with dependencies
    /// - Parameters:
    ///   - settings: Settings store for aliases and colors
    ///   - stats: Stats manager for tracking display switches
    ///   - powerMonitor: Power state monitor for battery-aware polling
    func inject(
        settings: SettingsStore,
        stats: StatsManager,
        powerMonitor: PowerStateMonitor? = nil
    ) {
        self.settings = settings
        self.stats = stats
        self.powerMonitor = powerMonitor

        logger.info("DisplayTracker initialized with dependencies")

        setupMouseMonitors()
        setupDisplayObserver()
        startTimers()

        // Initial detection on launch
        refreshDisplayList()
        updateCurrentDisplay()
    }

    /// Update polling mode based on power state
    /// - Parameter conservePower: True to reduce polling frequency
    func updatePollingMode(conservePower: Bool) {
        let shouldUpdate = stateQueue.sync { () -> Bool in
            guard conservePower != isConservingPower else { return false }
            isConservingPower = conservePower
            return true
        }

        guard shouldUpdate else { return }

        logger.info("Polling mode changed: \(conservePower ? "power saving" : "normal")")

        // Restart timers with new intervals
        startTimers()
    }

    /// Refresh the list of all connected displays
    func refreshDisplayList() {
        var result: [DisplayInfo] = []
        let mouseLocation = NSEvent.mouseLocation

        // Method 1: Use NSScreen.screens (primary method)
        for screen in NSScreen.screens {
            if let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID {
                let info = createDisplayInfo(
                    displayID: displayID,
                    screen: screen,
                    mouseLocation: mouseLocation
                )
                result.append(info)
            }
        }

        // Method 2: Use CGGetOnlineDisplayList to find displays NSScreen missed
        result.append(contentsOf: findAdditionalDisplays(
            existingIDs: Set(result.map { $0.id }),
            mouseLocation: mouseLocation,
            useOnlineList: true
        ))

        // Method 3: Check CGGetActiveDisplayList for any we missed
        result.append(contentsOf: findAdditionalDisplays(
            existingIDs: Set(result.map { $0.id }),
            mouseLocation: mouseLocation,
            useOnlineList: false
        ))

        allDisplays = result

        logger.debug("Display list refreshed: \(result.count) displays found")
    }

    // MARK: - Private Setup Methods

    private func setupMouseMonitors() {
        // Track mouse globally (when other apps are focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentDisplay()
            }
        }

        // Track mouse locally (when our app windows are focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] evt in
            Task { @MainActor in
                self?.updateCurrentDisplay()
            }
            return evt
        }

        logger.debug("Mouse monitors setup")
    }

    private func setupDisplayObserver() {
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            logger.debug("Screen parameters changed")
            Task { @MainActor [weak self] in
                self?.refreshDisplayList()
                self?.updateCurrentDisplay()
            }
        }
    }

    private func startTimers() {
        // Cancel existing timers
        displayRefreshCancellable?.cancel()
        universalControlCancellable?.cancel()

        // Adjust intervals based on power state (thread-safe read)
        let conservingPower = stateQueue.sync { isConservingPower }
        let refreshInterval = conservingPower
            ? Constants.Timing.displayRefreshInterval * 2  // 4s on battery
            : Constants.Timing.displayRefreshInterval      // 2s on AC

        // Display refresh timer using Combine
        displayRefreshCancellable = Timer.publish(
            every: refreshInterval,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.refreshDisplayList()
        }

        // Universal Control detection timer
        startUniversalControlTimer(fast: false)

        logger.debug("Timers started (power saving: \(conservingPower))")
    }

    /// Remove event monitors - nonisolated for deinit access
    nonisolated private func removeMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Universal Control Detection

    private func startUniversalControlTimer(fast: Bool) {
        universalControlCancellable?.cancel()

        // Use longer intervals when on battery (thread-safe read/write)
        let interval = stateQueue.sync { () -> TimeInterval in
            let baseInterval = fast
                ? Constants.Timing.fastPollingInterval
                : Constants.Timing.slowPollingInterval
            isInFastPollingMode = fast
            return isConservingPower ? baseInterval * 2 : baseInterval
        }

        universalControlCancellable = Timer.publish(
            every: interval,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.checkForUniversalControl()
        }
    }

    private func checkForUniversalControl() {
        let point = NSEvent.mouseLocation
        let isAtScreenEdge = isPositionAtScreenEdge(point)

        // Thread-safe state access and updates
        // All internal state reads/writes happen inside the sync block
        let result: UCCheckResult = stateQueue.sync {
            let positionUnchanged = (
                abs(point.x - lastMousePosition.x) < 1 &&
                abs(point.y - lastMousePosition.y) < 1
            )

            // Determine if we need to switch polling modes
            let switchToFast = isAtScreenEdge && !isInFastPollingMode
            let switchToSlow = (
                !isAtScreenEdge && isInFastPollingMode
                && !isOnUniversalControlInternal
            )

            // Update stuck counter
            if isAtScreenEdge && positionUnchanged {
                stuckAtEdgeCount += 1
            } else {
                stuckAtEdgeCount = 0
            }

            lastMousePosition = point

            let requiredStuckCount = isInFastPollingMode
                ? Constants.Display.fastModeStuckThreshold
                : Constants.Display.slowModeStuckThreshold
            let likelyOnUC = stuckAtEdgeCount >= requiredStuckCount
            let wasOnUC = isOnUniversalControlInternal

            return UCCheckResult(
                shouldSwitchToFast: switchToFast,
                shouldSwitchToSlow: switchToSlow,
                likelyOnUC: likelyOnUC,
                wasOnUC: wasOnUC
            )
        }

        // Handle polling mode switches outside sync block
        if result.shouldSwitchToFast {
            startUniversalControlTimer(fast: true)
        } else if result.shouldSwitchToSlow {
            startUniversalControlTimer(fast: false)
        }

        if result.likelyOnUC {
            if !result.wasOnUC {
                // Update internal state first (thread-safe) - use sync for consistency
                stateQueue.sync { self.isOnUniversalControlInternal = true }
                // Update @Published property
                isOnUniversalControl = true
                let name = settings?.aliases[Constants.SpecialKeys.universalControl]
                    ?? Constants.Defaults.universalControlName
                setDisplay(name: name, id: nil)
                logger.info("Universal Control detected - cursor on external device")
            }
        } else {
            if result.wasOnUC {
                // Update internal state first (thread-safe) - use sync for consistency
                stateQueue.sync {
                    self.isOnUniversalControlInternal = false
                    self.stuckAtEdgeCount = 0
                }
                // Update @Published property
                isOnUniversalControl = false
                updateCurrentDisplay()
                logger.info("Universal Control ended - cursor back on Mac")
            }
        }
    }

    private func isPositionAtScreenEdge(_ point: NSPoint) -> Bool {
        let edgeThreshold = Constants.Display.edgeThreshold
        let screens = NSScreen.screens  // Snapshot to avoid iteration issues

        for screen in screens {
            let frame = screen.frame

            let inScreenX = point.x >= frame.minX - edgeThreshold &&
                            point.x <= frame.maxX + edgeThreshold
            let inScreenY = point.y >= frame.minY - edgeThreshold &&
                            point.y <= frame.maxY + edgeThreshold

            if inScreenX && inScreenY {
                let atLeftEdge = abs(point.x - frame.minX) < edgeThreshold
                let atRightEdge = abs(point.x - frame.maxX) < edgeThreshold
                let atBottomEdge = abs(point.y - frame.minY) < edgeThreshold
                let atTopEdge = abs(point.y - frame.maxY) < edgeThreshold

                if atLeftEdge || atRightEdge || atBottomEdge || atTopEdge {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Display Detection

    private func updateCurrentDisplay() {
        let point = NSEvent.mouseLocation

        // First, try to find the display in our cached list
        if let display = allDisplays.first(where: { NSMouseInRect(point, $0.frame, false) }) {
            let key = String(display.id)
            let name = resolveDisplayName(
                key: key,
                fallbackName: display.name,
                isSidecar: display.isSidecarGuess
            )
            setDisplay(name: name, id: display.id)
            return
        }

        // Fallback: Check NSScreen.screens directly
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) {
            if let id = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID {
                let key = String(id)
                let isSidecar = isSidecarDisplay(id)
                let name = resolveDisplayName(
                    key: key,
                    fallbackName: screen.localizedName,
                    isSidecar: isSidecar
                )
                setDisplay(name: name, id: id)
                return
            }
            setDisplay(name: screen.localizedName, id: nil)
            return
        }

        // Mouse is outside all known screens - try CoreGraphics
        if let displayID = getDisplayIDAtPoint(point) {
            let isSidecar = isSidecarDisplay(displayID)
            let key = String(displayID)
            let name = resolveDisplayName(
                key: key,
                fallbackName: "Display \(displayID)",
                isSidecar: isSidecar
            )
            setDisplay(name: name, id: displayID)
            return
        }

        // Final fallback - cursor is outside all screens (Universal Control)
        let universalControlName = settings?.aliases[Constants.SpecialKeys.universalControl]
            ?? Constants.Defaults.universalControlName
        setDisplay(name: universalControlName, id: nil)

        // Update internal state first (thread-safe) - use sync for consistency
        stateQueue.sync { self.isOnUniversalControlInternal = true }
        // Update @Published property
        isOnUniversalControl = true
    }

    private func resolveDisplayName(key: String, fallbackName: String, isSidecar: Bool) -> String {
        if let alias = settings?.aliases[key] {
            return alias
        } else if isSidecar {
            return Constants.Defaults.universalControlName
        } else {
            return fallbackName
        }
    }

    private func setDisplay(name: String, id: CGDirectDisplayID?) {
        guard name != currentName else { return }

        lastDisplayID = id
        currentName = name
        currentDisplayID = id

        // Record stats by display ID (use special key for Universal Control)
        let statsKey = id.map { String($0) } ?? Constants.SpecialKeys.universalControl
        stats?.record(switchTo: statsKey)

        // Announce to VoiceOver users
        AccessibilityAnnouncer.shared.announceDisplayChange(name)

        logger.debug("Display changed to: '\(name)'")
    }

    // MARK: - Display Info Creation

    private func createDisplayInfo(
        displayID: CGDirectDisplayID,
        screen: NSScreen,
        mouseLocation: NSPoint
    ) -> DisplayInfo {
        let vendorID = CGDisplayVendorNumber(displayID)
        let modelID = CGDisplayModelNumber(displayID)
        let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        let isMain = screen == NSScreen.main

        let nameHintsSidecar = DisplayInfo.nameHintsSidecar(screen.localizedName)
        let isSidecarGuess = !isBuiltin && (
            nameHintsSidecar ||
            DisplayInfo.isSidecarDisplay(vendorID: vendorID, modelID: modelID, isBuiltin: isBuiltin)
        )

        return DisplayInfo(
            id: displayID,
            name: screen.localizedName,
            frame: screen.frame,
            isBuiltin: isBuiltin,
            isMain: isMain,
            vendorID: vendorID,
            modelID: modelID,
            isSidecarGuess: isSidecarGuess,
            isCurrentMouse: NSMouseInRect(mouseLocation, screen.frame, false),
            isMirrored: CGDisplayIsInMirrorSet(displayID) != 0,
            isActive: CGDisplayIsActive(displayID) != 0,
            isOnline: CGDisplayIsOnline(displayID) != 0
        )
    }

    private func createDisplayInfoFromCG(
        displayID: CGDirectDisplayID,
        mouseLocation: NSPoint
    ) -> DisplayInfo {
        let vendorID = CGDisplayVendorNumber(displayID)
        let modelID = CGDisplayModelNumber(displayID)
        let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        let isMain = CGDisplayIsMain(displayID) != 0

        let bounds = CGDisplayBounds(displayID)
        let frame = NSRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )

        let isSidecarGuess = DisplayInfo.isSidecarDisplay(
            vendorID: vendorID,
            modelID: modelID,
            isBuiltin: isBuiltin
        )

        let isMirrored = CGDisplayIsInMirrorSet(displayID) != 0

        let name: String
        if isSidecarGuess {
            name = isMirrored ? "iPad (Mirrored)" : "iPad (Sidecar)"
        } else if isBuiltin {
            name = "Built-in Display"
        } else {
            name = "External Display \(displayID)"
        }

        return DisplayInfo(
            id: displayID,
            name: name,
            frame: frame,
            isBuiltin: isBuiltin,
            isMain: isMain,
            vendorID: vendorID,
            modelID: modelID,
            isSidecarGuess: isSidecarGuess,
            isCurrentMouse: NSMouseInRect(mouseLocation, frame, false),
            isMirrored: isMirrored,
            isActive: CGDisplayIsActive(displayID) != 0,
            isOnline: CGDisplayIsOnline(displayID) != 0
        )
    }

    private func findAdditionalDisplays(
        existingIDs: Set<CGDirectDisplayID>,
        mouseLocation: NSPoint,
        useOnlineList: Bool
    ) -> [DisplayInfo] {
        var displays = [CGDirectDisplayID](repeating: 0, count: Constants.Display.maxDisplayCount)
        var count: UInt32 = 0

        if useOnlineList {
            CGGetOnlineDisplayList(UInt32(Constants.Display.maxDisplayCount), &displays, &count)
        } else {
            CGGetActiveDisplayList(UInt32(Constants.Display.maxDisplayCount), &displays, &count)
        }

        var result: [DisplayInfo] = []
        for i in 0..<Int(count) {
            let displayID = displays[i]
            if !existingIDs.contains(displayID) {
                result.append(createDisplayInfoFromCG(displayID: displayID, mouseLocation: mouseLocation))
            }
        }
        return result
    }

    private func getDisplayIDAtPoint(_ point: NSPoint) -> CGDirectDisplayID? {
        var displayID: CGDirectDisplayID = 0
        var displayCount: UInt32 = 0

        let cgPoint = CGPoint(x: point.x, y: point.y)
        let result = CGGetDisplaysWithPoint(cgPoint, 1, &displayID, &displayCount)

        if result == .success && displayCount > 0 {
            return displayID
        }
        return nil
    }

    private func isSidecarDisplay(_ displayID: CGDirectDisplayID) -> Bool {
        if CGDisplayIsBuiltin(displayID) != 0 {
            return false
        }

        let vendorID = CGDisplayVendorNumber(displayID)
        let modelID = CGDisplayModelNumber(displayID)

        // Check name hint first
        if let screen = NSScreen.screens.first(where: {
            let screenID = $0.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID
            return screenID == displayID
        }) {
            if DisplayInfo.nameHintsSidecar(screen.localizedName) {
                return true
            }
        }

        return DisplayInfo.isSidecarDisplay(
            vendorID: vendorID,
            modelID: modelID,
            isBuiltin: false
        )
    }
}
