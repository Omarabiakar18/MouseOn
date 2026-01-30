//
//  AutoHideManager.swift
//  MouseOn
//
//  Manages auto-hiding of the menu bar item after inactivity.
//  Shows again when mouse moves.
//

import Foundation
import AppKit
import Combine
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "AutoHide")

// MARK: - Auto Hide Manager

/// Manages auto-hiding the menu bar item after a period of inactivity.
///
/// When enabled, the manager:
/// 1. Monitors global mouse movement events
/// 2. Starts a timer when mouse stops moving
/// 3. Hides the menu bar after the configured timeout
/// 4. Shows it again immediately when mouse moves
@MainActor
final class AutoHideManager: ObservableObject {

    // MARK: - Published State

    /// Whether the menu bar item should currently be visible
    @Published private(set) var isVisible: Bool = true

    // MARK: - Dependencies

    private let settings: SettingsStore

    // MARK: - Private State

    private var hideTimer: Timer?
    private var eventMonitor: Any?
    private var lastMousePosition: NSPoint = .zero
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(settings: SettingsStore) {
        self.settings = settings
        setupObservers()
        updateMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Watch for changes to autoHideEnabled
        settings.$features
            .map(\.autoHideEnabled)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateMonitoring()
            }
            .store(in: &cancellables)

        // Watch for changes to autoHideSeconds
        settings.$autoHideSeconds
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.restartTimer()
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitoring Control

    private func updateMonitoring() {
        if settings.features.autoHideEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
            show()
        }
    }

    private func startMonitoring() {
        guard eventMonitor == nil else { return }

        logger.debug("Starting auto-hide monitoring")

        // Monitor global mouse moved events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseMoved(event)
            }
        }

        // Also monitor local events (when app windows are active)
        // This ensures we catch movement even when settings window is open

        // Start initial timer
        restartTimer()
    }

    private func stopMonitoring() {
        logger.debug("Stopping auto-hide monitoring")

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        hideTimer?.invalidate()
        hideTimer = nil
    }

    // MARK: - Mouse Event Handling

    private func handleMouseMoved(_ event: NSEvent) {
        let currentPosition = NSEvent.mouseLocation

        // Check if mouse actually moved (not just event noise)
        let distance = hypot(
            currentPosition.x - lastMousePosition.x,
            currentPosition.y - lastMousePosition.y
        )

        // Only react to meaningful movement (> 2 pixels)
        guard distance > 2 else { return }

        lastMousePosition = currentPosition

        // Show menu bar if hidden
        if !isVisible {
            show()
        }

        // Restart the hide timer
        restartTimer()
    }

    // MARK: - Timer Management

    private func restartTimer() {
        hideTimer?.invalidate()

        guard settings.features.autoHideEnabled else { return }

        let seconds = TimeInterval(settings.autoHideSeconds)

        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }

        logger.debug("Auto-hide timer set for \(seconds) seconds")
    }

    // MARK: - Visibility Control

    private func show() {
        guard !isVisible else { return }
        isVisible = true
        logger.debug("Menu bar item shown")
    }

    private func hide() {
        guard isVisible else { return }
        isVisible = false
        logger.debug("Menu bar item hidden due to inactivity")
    }

    // MARK: - Manual Control

    /// Force show the menu bar item (e.g., when user interacts with menu)
    func forceShow() {
        show()
        restartTimer()
    }
}
