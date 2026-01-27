//
//  HotkeyManager.swift
//  MouseOn
//
//  Manages global hotkeys for app features.
//

import AppKit
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "HotkeyManager")

// MARK: - Hotkey Manager

/// Manages global keyboard shortcuts
final class HotkeyManager {

    // MARK: - Shared Instance

    static let shared = HotkeyManager()

    // MARK: - Private Properties

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var settings: SettingsStore?

    // MARK: - Initialization

    private init() {}

    deinit {
        removeMonitors()
    }

    // MARK: - Public Methods

    /// Setup hotkey monitoring
    /// - Parameter settings: The settings store for configuration
    /// - Returns: True if global monitoring was successfully set up, false if accessibility permissions may be missing
    @discardableResult
    func setup(settings: SettingsStore) -> Bool {
        self.settings = settings

        // Remove existing monitors
        removeMonitors()

        logger.debug("Setting up hotkey monitors")

        // Monitor for ⌥⌘F (Option + Command + F) globally
        // This returns nil if accessibility permissions are not granted
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Also monitor locally when our windows are focused
        // Local monitoring doesn't require accessibility permissions
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        // Check if global monitoring was set up successfully
        if globalMonitor == nil {
            logger.warning("Global hotkey monitoring failed to initialize. Accessibility permissions may be required.")
            logger.warning("The Find My Cursor hotkey (⌥⌘F) will only work when MouseOn windows are focused.")
            // Local monitor should still work when our windows are focused
            if localMonitor != nil {
                logger.info("Local hotkey monitoring active (works when app windows are focused)")
            }
            return false
        }

        logger.info("Hotkey monitors active (global and local)")
        return true
    }

    // MARK: - Private Methods

    private func removeMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Check for ⌥⌘F (Option + Command + F) first (quick check, no main actor needed)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isOptionCommand = modifiers == [.option, .command]
        let isF = event.charactersIgnoringModifiers?.lowercased() == "f"

        guard isOptionCommand && isF else { return }

        // Dispatch to main actor since SettingsStore is @MainActor
        // and CursorHighlighter requires main thread
        Task { @MainActor in
            guard self.settings?.findCursorHotkeyEnabled == true else { return }

            logger.debug("Find cursor hotkey triggered")
            let color = self.settings?.getHighlightNSColor() ?? .systemOrange
            CursorHighlighter.shared.highlight(color: color)
        }
    }
}
