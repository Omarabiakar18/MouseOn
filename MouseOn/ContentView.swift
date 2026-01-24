//  MouseOnApp.swift
//  MouseOn
//  Created 18 Apr 2025
//
//  A tiny utility that shows which display the mouse pointer is on.
//  All rights reserved.

import SwiftUI
import AppKit
import CoreGraphics

@main
struct MouseOnApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var tracker  = DisplayTracker()
    @StateObject private var stats    = StatsManager()
    @Environment(\.openWindow) private var openWindow

    init() {
        // Hide Dock icon, run as background-only app
        NSApplication.shared.setActivationPolicy(.accessory)

        // Flush stats when app terminates
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Note: Can't access @StateObject here, but StatsManager saves on each switch
        }
    }

    /// Current screen name clipped to the user‑selected length, or "-" when unknown
    private var truncatedName: String {
        let raw = tracker.currentName.isEmpty ? "-" : tracker.currentName
        let limit = settings.maxNameLength
        return raw.count > limit ? String(raw.prefix(limit)) + "…" : raw
    }
    
    /// Color for the current display (if set)
    private var currentDisplayColor: Color {
        let displayKey: String
        if tracker.isOnUniversalControl {
            displayKey = "universal-control"
        } else if let id = tracker.currentDisplayID {
            displayKey = String(id)
        } else {
            return .primary
        }
        return settings.colorForDisplay(displayKey) ?? .primary
    }

    var body: some Scene {
        MenuBarExtra {
            Button("Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Stats") {
                openWindow(id: "stats")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Connected Displays") {
                openWindow(id: "displays-debug")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()
            
            Button("Find My Cursor") {
                CursorHighlighter.shared.highlight()
            }

            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            Text(truncatedName)
                .foregroundColor(currentDisplayColor)
                .onAppear {
                    tracker.inject(settings: settings, stats: stats)
                }
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "settings") {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(tracker)
        }
        .defaultSize(width: 420, height: 320)

        WindowGroup(id: "stats") {
            StatsView()
                .environmentObject(stats)
        }
        .defaultSize(width: 480, height: 260)

        WindowGroup(id: "displays-debug") {
            DisplaysDebugView()
                .environmentObject(tracker)
        }
        .defaultSize(width: 550, height: 400)
    }
}

// MARK: - Settings Store

final class SettingsStore: ObservableObject {
    struct FeatureToggles: Codable {
        var showDataBox        = true
        var autoHideEnabled    = true
        var statsEnabled       = true
    }

    @Published var features           = FeatureToggles()
    @Published var opacity: Double    = 0.75   // 0.30 – 1.00
    @Published var autoHideSeconds    = 30     // 5  – 300
    @Published var aliases: [String: String] = [:] // screenUUID ➜ custom name
    @Published var maxNameLength: Int = 15   // 5…30
    @Published var displayColors: [String: String] = [:] // screenUUID ➜ hex color

    init() {
        load()
    }

    func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "features"),
           let decoded = try? JSONDecoder().decode(FeatureToggles.self, from: data) {
            features = decoded
        }
        let storedOpacity = defaults.double(forKey: "opacity")
        opacity = storedOpacity == 0 ? 0.75 : storedOpacity.clamped(to: 0.30...1)

        let storedSecs = defaults.integer(forKey: "autoHideSeconds")
        autoHideSeconds = storedSecs == 0 ? 30 : storedSecs.clamped(to: 5...300)
        if let aliasData = defaults.dictionary(forKey: "aliases") as? [String: String] {
            aliases = aliasData
        }
        let storedLen = defaults.integer(forKey: "maxNameLength")
        maxNameLength = (5...30).contains(storedLen) ? storedLen : 15
        if let colorData = defaults.dictionary(forKey: "displayColors") as? [String: String] {
            displayColors = colorData
        }
    }

    func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(features) {
            defaults.set(data, forKey: "features")
        }
        defaults.set(opacity, forKey: "opacity")
        defaults.set(autoHideSeconds, forKey: "autoHideSeconds")
        defaults.set(aliases, forKey: "aliases")
        defaults.set(maxNameLength, forKey: "maxNameLength")
        defaults.set(displayColors, forKey: "displayColors")
    }
    
    /// Get Color for a display ID, returns nil if not set
    func colorForDisplay(_ displayID: String) -> Color? {
        guard let hex = displayColors[displayID] else { return nil }
        return Color(hex: hex)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Display Info

struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let isBuiltin: Bool
    let isMain: Bool
    let vendorID: UInt32
    let modelID: UInt32
    let isSidecarGuess: Bool
    let isCurrentMouse: Bool
    let isMirrored: Bool       // NEW: Is this display in a mirror set?
    let isActive: Bool         // NEW: Is this display active (drawable)?
    let isOnline: Bool         // NEW: Is this display online?
}

// MARK: - Display Tracker

final class DisplayTracker: ObservableObject {
    @Published private(set) var currentName: String = ""  // published for DataBoxView
    @Published private(set) var currentDisplayID: CGDirectDisplayID?
    @Published private(set) var allDisplays: [DisplayInfo] = []  // All detected displays
    @Published private(set) var isOnUniversalControl: Bool = false  // NEW: Cursor on another device

    private var globalMonitor: Any?
    private var localMonitor: Any?  // Also track when app windows are focused
    private weak var stats: StatsManager?
    private weak var settings: SettingsStore?
    private var lastDisplayID: CGDirectDisplayID?
    private var displayObserver: Any?
    private var pollTimer: Timer?
    private var universalControlTimer: Timer?  // NEW: Timer to detect Universal Control
    private var lastMousePosition: NSPoint = .zero  // Track last mouse position
    private var stuckAtEdgeCount: Int = 0  // Count consecutive checks at screen edge
    private var isInFastPollingMode: Bool = false  // Adaptive polling mode

    deinit {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        pollTimer?.invalidate()
        universalControlTimer?.invalidate()
    }

    func inject(settings: SettingsStore, stats: StatsManager) {
        self.settings = settings
        self.stats    = stats

        // Track mouse globally (when other apps are focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.updateCurrentDisplay()
        }

        // Track mouse locally (when our app windows are focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] evt in
            self?.updateCurrentDisplay()
            return evt
        }

        // Listen for display configuration changes (Sidecar connect/disconnect)
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDisplayList()
            self?.updateCurrentDisplay()
        }

        // Poll for display changes every 2 seconds (backup for Sidecar detection)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshDisplayList()
        }
        
        // Universal Control detection - adaptive polling
        // Start with slow polling (1s), switches to fast (100ms) when cursor near edge
        startUniversalControlTimer(fast: false)

        // Initial detection on launch
        refreshDisplayList()
        updateCurrentDisplay()
    }
    
    /// Start/restart the Universal Control timer with adaptive interval
    private func startUniversalControlTimer(fast: Bool) {
        universalControlTimer?.invalidate()
        let interval = fast ? 0.1 : 1.0  // 100ms when near edge, 1s otherwise
        isInFastPollingMode = fast
        universalControlTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUniversalControl()
        }
    }
    
    /// NEW: Check if cursor has left all Mac screens (Universal Control)
    private func checkForUniversalControl() {
        let point = NSEvent.mouseLocation
        
        // Check if mouse position is at a screen edge
        let isAtScreenEdge = isPositionAtScreenEdge(point)
        
        // Check if mouse position hasn't changed (stuck)
        let positionUnchanged = (abs(point.x - lastMousePosition.x) < 1 && abs(point.y - lastMousePosition.y) < 1)
        
        // Adaptive polling: switch to fast mode when near edge, slow mode otherwise
        if isAtScreenEdge && !isInFastPollingMode {
            startUniversalControlTimer(fast: true)
        } else if !isAtScreenEdge && isInFastPollingMode && !isOnUniversalControl {
            startUniversalControlTimer(fast: false)
        }
        
        // Update stuck counter
        if isAtScreenEdge && positionUnchanged {
            stuckAtEdgeCount += 1
        } else {
            stuckAtEdgeCount = 0
        }
        
        // Save current position for next check
        lastMousePosition = point
        
        // In fast mode: 3 checks = 300ms, In slow mode: 2 checks = 2s
        let requiredStuckCount = isInFastPollingMode ? 3 : 2
        let likelyOnUniversalControl = stuckAtEdgeCount >= requiredStuckCount
        
        if likelyOnUniversalControl {
            // Cursor is stuck at screen edge - likely on iPad via Universal Control
            if !isOnUniversalControl {
                DispatchQueue.main.async {
                    self.isOnUniversalControl = true
                }
                let name = settings?.aliases["universal-control"] ?? "iPad"
                setDisplay(name: name, id: nil)
            }
        } else {
            // Cursor is moving or not at edge - back on Mac
            if isOnUniversalControl {
                DispatchQueue.main.async {
                    self.isOnUniversalControl = false
                }
                stuckAtEdgeCount = 0
                updateCurrentDisplay()
            }
        }
    }
    
    /// Check if a point is at any screen edge (within 5 pixels)
    private func isPositionAtScreenEdge(_ point: NSPoint) -> Bool {
        let edgeThreshold: CGFloat = 5
        
        for screen in NSScreen.screens {
            let frame = screen.frame
            let minX = frame.minX
            let maxX = frame.maxX
            let minY = frame.minY
            let maxY = frame.maxY
            
            // Check if point is within the screen's bounds (with some tolerance)
            let inScreenX = point.x >= minX - edgeThreshold && point.x <= maxX + edgeThreshold
            let inScreenY = point.y >= minY - edgeThreshold && point.y <= maxY + edgeThreshold
            
            if inScreenX && inScreenY {
                // Check if at any edge
                let atLeftEdge = abs(point.x - minX) < edgeThreshold
                let atRightEdge = abs(point.x - maxX) < edgeThreshold
                let atBottomEdge = abs(point.y - minY) < edgeThreshold
                let atTopEdge = abs(point.y - maxY) < edgeThreshold
                
                if atLeftEdge || atRightEdge || atBottomEdge || atTopEdge {
                    return true
                }
            }
        }
        return false
    }

    /// Refresh the list of all connected displays using multiple detection methods
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
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        var onlineCount: UInt32 = 0
        CGGetOnlineDisplayList(16, &onlineDisplays, &onlineCount)

        for i in 0..<Int(onlineCount) {
            let displayID = onlineDisplays[i]
            // Skip if already found via NSScreen
            if result.contains(where: { $0.id == displayID }) {
                continue
            }

            // This display was found by CG but not NSScreen - could be Sidecar!
            let info = createDisplayInfoFromCG(
                displayID: displayID,
                mouseLocation: mouseLocation
            )
            result.append(info)
        }

        // Method 3: Check CGGetActiveDisplayList for any we missed
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        var activeCount: UInt32 = 0
        CGGetActiveDisplayList(16, &activeDisplays, &activeCount)

        for i in 0..<Int(activeCount) {
            let displayID = activeDisplays[i]
            if result.contains(where: { $0.id == displayID }) {
                continue
            }
            let info = createDisplayInfoFromCG(
                displayID: displayID,
                mouseLocation: mouseLocation
            )
            result.append(info)
        }

        DispatchQueue.main.async {
            self.allDisplays = result
        }
    }

    private func createDisplayInfo(
        displayID: CGDirectDisplayID,
        screen: NSScreen,
        mouseLocation: NSPoint
    ) -> DisplayInfo {
        let vendorID = CGDisplayVendorNumber(displayID)
        let modelID = CGDisplayModelNumber(displayID)
        let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        let isMain = screen == NSScreen.main

        let nameHintsSidecar = screen.localizedName.lowercased().contains("sidecar") ||
                               screen.localizedName.lowercased().contains("ipad")
        let isAppleVendor = vendorID == 0x610 || vendorID == 1552
        let isVirtualModel = modelID == 0 || modelID >= 0xA000
        let isSidecarGuess = !isBuiltin && (nameHintsSidecar || (isAppleVendor && isVirtualModel))

        let isCurrentMouse = NSMouseInRect(mouseLocation, screen.frame, false)
        
        // NEW: Check mirror and active status
        let isMirrored = CGDisplayIsInMirrorSet(displayID) != 0
        let isActive = CGDisplayIsActive(displayID) != 0
        let isOnline = CGDisplayIsOnline(displayID) != 0

        return DisplayInfo(
            id: displayID,
            name: screen.localizedName,
            frame: screen.frame,
            isBuiltin: isBuiltin,
            isMain: isMain,
            vendorID: vendorID,
            modelID: modelID,
            isSidecarGuess: isSidecarGuess,
            isCurrentMouse: isCurrentMouse,
            isMirrored: isMirrored,
            isActive: isActive,
            isOnline: isOnline
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

        // Get display bounds from CoreGraphics
        let bounds = CGDisplayBounds(displayID)
        let frame = NSRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )

        // Determine name - check if it might be Sidecar
        let isAppleVendor = vendorID == 0x610 || vendorID == 1552
        let isVirtualModel = modelID == 0 || modelID >= 0xA000
        let isSidecarGuess = !isBuiltin && isAppleVendor && isVirtualModel
        
        // NEW: Check mirror and active status
        let isMirrored = CGDisplayIsInMirrorSet(displayID) != 0
        let isActive = CGDisplayIsActive(displayID) != 0
        let isOnline = CGDisplayIsOnline(displayID) != 0

        let name: String
        if isSidecarGuess {
            name = isMirrored ? "iPad (Mirrored)" : "iPad (Sidecar)"
        } else if isBuiltin {
            name = "Built-in Display"
        } else {
            name = "External Display \(displayID)"
        }

        // Check if mouse is in this display's bounds
        let isCurrentMouse = NSMouseInRect(mouseLocation, frame, false)

        return DisplayInfo(
            id: displayID,
            name: name,
            frame: frame,
            isBuiltin: isBuiltin,
            isMain: isMain,
            vendorID: vendorID,
            modelID: modelID,
            isSidecarGuess: isSidecarGuess,
            isCurrentMouse: isCurrentMouse,
            isMirrored: isMirrored,
            isActive: isActive,
            isOnline: isOnline
        )
    }

    private func updateCurrentDisplay() {
        let point = NSEvent.mouseLocation

        // First, try to find the display in our cached list
        if let display = allDisplays.first(where: { NSMouseInRect(point, $0.frame, false) }) {
            let key = String(display.id)
            let name: String
            if let alias = settings?.aliases[key] {
                name = alias
            } else if display.isSidecarGuess {
                name = "iPad"
            } else {
                name = display.name
            }
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

                let name: String
                if let alias = settings?.aliases[key] {
                    name = alias
                } else if isSidecar {
                    name = "iPad"
                } else {
                    name = screen.localizedName
                }
                setDisplay(name: name, id: id)
                return
            }
            setDisplay(name: screen.localizedName, id: nil)
            return
        }

        // Mouse is outside all known screens - likely on Sidecar/iPad not yet detected
        // Try to detect using CGDisplayID at mouse location
        if let displayID = getDisplayIDAtPoint(point) {
            let isSidecar = isSidecarDisplay(displayID)
            let key = String(displayID)

            let name: String
            if let alias = settings?.aliases[key] {
                name = alias
            } else if isSidecar {
                name = "iPad"
            } else {
                name = "Display \(displayID)"
            }
            setDisplay(name: name, id: displayID)
            return
        }

        // Final fallback - cursor is outside all screens
        // This is likely Universal Control (iPad as separate device)
        // Use the alias for "universal-control" if set, otherwise default to "iPad"
        let universalControlName = settings?.aliases["universal-control"] ?? "iPad"
        setDisplay(name: universalControlName, id: nil)
        
        DispatchQueue.main.async {
            self.isOnUniversalControl = true
        }
    }

    /// Get the CGDirectDisplayID for the display containing a point
    private func getDisplayIDAtPoint(_ point: NSPoint) -> CGDirectDisplayID? {
        var displayID: CGDirectDisplayID = 0
        var displayCount: UInt32 = 0

        // Convert NSPoint to CGPoint (flip Y coordinate for CG coordinate system)
        let cgPoint = CGPoint(x: point.x, y: point.y)

        let result = CGGetDisplaysWithPoint(cgPoint, 1, &displayID, &displayCount)
        if result == .success && displayCount > 0 {
            return displayID
        }
        return nil
    }

    /// Detect if a display is a Sidecar (iPad) display using CoreGraphics
    private func isSidecarDisplay(_ displayID: CGDirectDisplayID) -> Bool {
        // Sidecar displays have specific characteristics:
        // 1. They are NOT the built-in display
        // 2. They have a specific vendor ID (Apple = 0x610 or 1552)
        // 3. Model number for Sidecar is typically 0xA030 or similar virtual display IDs

        // Check if it's built-in (definitely not Sidecar)
        if CGDisplayIsBuiltin(displayID) != 0 {
            return false
        }

        let vendorID = CGDisplayVendorNumber(displayID)
        let modelID = CGDisplayModelNumber(displayID)

        // Apple vendor ID is 0x610 (1552 in decimal)
        // Sidecar virtual displays typically have model numbers in the 0xA000+ range
        // or they may report as model 0 with Apple vendor
        let isAppleVendor = vendorID == 0x610 || vendorID == 1552
        let isVirtualModel = modelID == 0 || modelID >= 0xA000

        // Additional check: Sidecar displays typically have "Sidecar" in their name
        // before any alias is applied
        if let screen = NSScreen.screens.first(where: {
            let screenID = $0.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID
            return screenID == displayID
        }) {
            let localName = screen.localizedName.lowercased()
            if localName.contains("sidecar") || localName.contains("ipad") {
                return true
            }
        }

        return isAppleVendor && isVirtualModel
    }

    private func setDisplay(name: String, id: CGDirectDisplayID?) {
        guard name != currentName else { return }

        lastDisplayID = id

        DispatchQueue.main.async {
            self.currentName = name
            self.currentDisplayID = id
        }
        stats?.record(switchTo: name)
    }
}

// MARK: - Auto Fade Manager

final class AutoFadeManager: ObservableObject {
    @Published var visible = true
    private var timer: Timer?
    private weak var settings: SettingsStore?

    func inject(settings: SettingsStore) {
        self.settings = settings
        schedule()
    }

    func pointerMoved() {
        guard settings?.features.autoHideEnabled == true else { return }
        visible = true
        schedule()
    }

    private func schedule() {
        timer?.invalidate()
        guard let secs = settings?.autoHideSeconds else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(secs), repeats: false) { [weak self] _ in
            self?.visible = false
        }
    }
}

// MARK: - Cursor Highlighter

final class CursorHighlighter {
    static let shared = CursorHighlighter()
    
    private var overlayWindow: NSWindow?
    private var animationTimer: Timer?
    private var animationPhase: CGFloat = 0
    private var dismissWorkItem: DispatchWorkItem?
    
    private init() {}
    
    func highlight() {
        // Ensure we're on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.highlight()
            }
            return
        }
        
        // Remove any existing overlay
        dismiss()
        
        // Get cursor position
        let mouseLocation = NSEvent.mouseLocation
        
        // Create overlay window
        let windowSize: CGFloat = 200
        let windowRect = NSRect(
            x: mouseLocation.x - windowSize / 2,
            y: mouseLocation.y - windowSize / 2,
            width: windowSize,
            height: windowSize
        )
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false  // Prevent premature deallocation
        
        let highlightView = CursorHighlightView(frame: NSRect(origin: .zero, size: windowRect.size))
        window.contentView = highlightView
        
        window.orderFrontRegardless()
        overlayWindow = window
        
        // Animate
        animationPhase = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, let window = self.overlayWindow else {
                timer.invalidate()
                return
            }
            self.animationPhase += 0.05
            if let view = window.contentView as? CursorHighlightView {
                view.phase = self.animationPhase
                view.needsDisplay = true
            }
        }
        
        // Auto-dismiss after 1.5 seconds
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }
    
    private func dismiss() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.dismiss()
            }
            return
        }
        
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        
        animationTimer?.invalidate()
        animationTimer = nil
        
        if let window = overlayWindow {
            window.orderOut(nil)
            overlayWindow = nil
        }
    }
}

// Custom view for drawing animated circles
final class CursorHighlightView: NSView {
    var phase: CGFloat = 0
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxRadius = min(bounds.width, bounds.height) / 2
        
        // Draw multiple expanding circles
        for i in 0..<3 {
            let offset = CGFloat(i) * 0.33
            let progress = (phase + offset).truncatingRemainder(dividingBy: 1.0)
            let radius = maxRadius * progress
            let alpha = 1.0 - progress
            
            context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(alpha * 0.8).cgColor)
            context.setLineWidth(3.0)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.strokePath()
        }
        
        // Draw center dot
        context.setFillColor(NSColor.systemOrange.cgColor)
        context.addArc(center: center, radius: 8, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.fillPath()
    }
}

// MARK: - Stats Manager

final class StatsManager: ObservableObject {
    @Published private(set) var data: [String: TimeInterval] = [:]
    @Published private(set) var totalSwitches: Int = 0

    private var currentName: String?
    private var startTime = Date()
    private let statsURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupport.appendingPathComponent("MouseOn", isDirectory: true)

        // Ensure app folder exists
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        statsURL = appFolder.appendingPathComponent("stats.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: statsURL),
              let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return
        }
        self.data = decoded
    }

    func record(switchTo name: String) {
        let elapsed = Date().timeIntervalSince(startTime)
        if let cur = currentName {
            data[cur, default: 0] += elapsed
        }
        currentName = name
        startTime = Date()
        totalSwitches += 1
        save()
    }

    /// Flush current session time (call before app terminates)
    func flush() {
        guard let cur = currentName else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        data[cur, default: 0] += elapsed
        startTime = Date()
        save()
    }

    func resetStats() {
        data = [:]
        totalSwitches = 0
        save()
    }

    private func save() {
        try? JSONEncoder().encode(data).write(to: statsURL)
    }
}

// MARK: - Settings UI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var tracker: DisplayTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabView {
                AppearanceTab().tabItem { Text("Appearance") }
                BehaviorTab()  .tabItem { Text("Behavior")   }
                DisplaysTab()  .tabItem { Text("Displays")   }
            }

        }
        .padding()
        .frame(minWidth: 380, minHeight: 280)
    }

    // MARK: Tabs

    struct AppearanceTab: View {
        @EnvironmentObject var settings: SettingsStore
        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text("Displayed characters")
                    Stepper(value: $settings.maxNameLength, in: 5...30) {
                        Text("\(settings.maxNameLength)")
                    }
                }
                Spacer()
            }
            .onDisappear { settings.save() }
        }
    }

    struct BehaviorTab: View {
        @EnvironmentObject var settings: SettingsStore
        var body: some View {
            VStack(alignment: .leading) {
                Toggle("Collect pointer‑time stats", isOn: $settings.features.statsEnabled)
                Spacer()
            }
            .onDisappear { settings.save() }
        }
    }

    struct DisplaysTab: View {
        @EnvironmentObject var settings: SettingsStore
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Mac displays
                ForEach(Array(NSScreen.screens.enumerated()), id: \.element.localizedName) { _, scr in
                    let screenNumKey = NSDeviceDescriptionKey("NSScreenNumber")
                    if let displayID = scr.deviceDescription[screenNumKey] as? CGDirectDisplayID {
                        let uuid = String(displayID)
                        let nameBinding = Binding(
                            get: { settings.aliases[uuid] ?? scr.localizedName },
                            set: { settings.aliases[uuid] = $0 })
                        let colorBinding = Binding(
                            get: { settings.colorForDisplay(uuid) ?? .primary },
                            set: { settings.displayColors[uuid] = $0.toHex() })
                        HStack {
                            Text(scr.localizedName)
                            Spacer()
                            ColorPicker("", selection: colorBinding)
                                .labelsHidden()
                                .frame(width: 30)
                            TextField("Alias", text: nameBinding)
                                .frame(width: 120)
                            Button(action: { NSApp.orderFrontCharacterPalette(nil) }) {
                                Image(systemName: "face.smiling")
                            }
                            .buttonStyle(.borderless)
                            .help("Open Emoji Picker")
                        }
                    } else {
                        EmptyView()
                    }
                }
                
                Divider()
                
                // Universal Control (iPad via keyboard/mouse sharing)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Universal Control")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let ucBinding = Binding(
                        get: { settings.aliases["universal-control"] ?? "iPad" },
                        set: { settings.aliases["universal-control"] = $0 })
                    let ucColorBinding = Binding(
                        get: { settings.colorForDisplay("universal-control") ?? .primary },
                        set: { settings.displayColors["universal-control"] = $0.toHex() })
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "ipad")
                            Text("iPad (via Universal Control)")
                        }
                        Spacer()
                        ColorPicker("", selection: ucColorBinding)
                            .labelsHidden()
                            .frame(width: 30)
                        TextField("Name", text: ucBinding)
                            .frame(width: 120)
                        Button(action: { NSApp.orderFrontCharacterPalette(nil) }) {
                            Image(systemName: "face.smiling")
                        }
                        .buttonStyle(.borderless)
                        .help("Open Emoji Picker")
                    }
                }
                
                Spacer()
            }
            .onDisappear { settings.save() }
        }
    }
}

// MARK: - Stats View

struct StatsView: View {
    @EnvironmentObject var stats: StatsManager
    @State private var showResetConfirm = false

    var body: some View {
        VStack {
            Text("Pointer Time per Display")
                .font(.headline)

            if stats.data.isEmpty {
                Spacer()
                Text("No data yet")
                    .foregroundColor(.secondary)
                Text("Move your mouse between displays to start tracking")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(stats.data.sorted(by: { $0.value > $1.value }), id: \.key) { name, seconds in
                    HStack {
                        Text(name)
                        Spacer()
                        Text(timeString(seconds))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }

                Text("Total display switches: \(stats.totalSwitches)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Reset") { showResetConfirm = true }
                    .foregroundColor(.red)
                Spacer()
                Button("Close") { NSApp.keyWindow?.close() }
            }
        }
        .padding()
        .alert("Reset Statistics?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { stats.resetStats() }
        } message: {
            Text("This will permanently delete all tracked display time.")
        }
    }

    private func timeString(_ sec: TimeInterval) -> String {
        let hours = Int(sec) / 3600
        let minutes = Int(sec.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(sec.truncatingRemainder(dividingBy: 60))
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MouseOnApp_Previews: PreviewProvider {
    static var previews: some View {
        Text("MouseOn menu‑bar utility")
            .padding()
    }
}
#endif

// MARK: - Displays Debug View

struct DisplaysDebugView: View {
    @EnvironmentObject var tracker: DisplayTracker
    @State private var mouseLocation: NSPoint = .zero
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Connected Displays")
                        .font(.headline)
                    Spacer()
                    Button("Refresh") {
                        tracker.refreshDisplayList()
                        mouseLocation = NSEvent.mouseLocation
                    }
                }

                let currentDisplay = tracker.currentName.isEmpty ? "-" : tracker.currentName
                Text("Mouse: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y))) → \(currentDisplay)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Universal Control indicator
                if tracker.isOnUniversalControl {
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
                }

                Divider()

                if tracker.allDisplays.isEmpty {
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
            } else {
                List(tracker.allDisplays) { display in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if display.isCurrentMouse {
                                Image(systemName: "cursorarrow")
                                    .foregroundColor(.accentColor)
                            }
                            Text(display.name)
                                .fontWeight(display.isCurrentMouse ? .bold : .regular)
                            Spacer()
                            if display.isMain {
                                Text("Main")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            if display.isBuiltin {
                                Text("Built-in")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            if display.isSidecarGuess {
                                Text("Sidecar?")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            if display.isMirrored {
                                Text("MIRRORED")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.3))
                                    .cornerRadius(4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("ID: \(display.id)")
                            let vendorHex = String(display.vendorID, radix: 16, uppercase: true)
                            Text("Vendor: 0x\(vendorHex) (\(display.vendorID))")
                            let modelHex = String(display.modelID, radix: 16, uppercase: true)
                            Text("Model: 0x\(modelHex) (\(display.modelID))")
                            let x = Int(display.frame.origin.x)
                            let y = Int(display.frame.origin.y)
                            let w = Int(display.frame.width)
                            let h = Int(display.frame.height)
                            Text("Frame: \(x),\(y) \(w)×\(h)")
                            // NEW: Show status flags
                            HStack(spacing: 8) {
                                Text("Online: \(display.isOnline ? "✓" : "✗")")
                                Text("Active: \(display.isActive ? "✓" : "✗")")
                                Text("Mirrored: \(display.isMirrored ? "⚠️ YES" : "No")")
                            }
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

                Divider()

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

                // Show warning if any display is mirrored
                if tracker.allDisplays.contains(where: { $0.isMirrored }) {
                    Divider()
                    
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
                }
                
                if tracker.allDisplays.count == 1 && NSScreen.screens.count == 1 && !tracker.allDisplays.contains(where: { $0.isMirrored }) {
                    Divider()

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

                HStack {
                    Spacer()
                    Button("Close") { NSApp.keyWindow?.close() }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            tracker.refreshDisplayList()
            mouseLocation = NSEvent.mouseLocation
            // Update mouse location periodically
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                mouseLocation = NSEvent.mouseLocation
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

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
