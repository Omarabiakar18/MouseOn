//
//  LargeCursorManager.swift
//  MouseOn
//
//  Provides large cursor mode - temporarily enlarges cursor visibility.
//  Alternative to Find My Cursor for users who prefer a larger pointer.
//

import AppKit
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "LargeCursor")

// MARK: - Large Cursor Manager

/// Manages large cursor overlay for enhanced visibility
final class LargeCursorManager {

    // MARK: - Shared Instance

    static let shared = LargeCursorManager()

    // MARK: - Configuration

    /// Size multiplier for the large cursor (2x = twice as big)
    var sizeMultiplier: CGFloat = 3.0

    /// How long to show the large cursor (seconds)
    var displayDuration: TimeInterval = 5.0

    /// Color for the cursor overlay
    var cursorColor: NSColor = .white

    // MARK: - Private Properties

    private var overlayWindow: NSWindow?
    private var trackingTimer: Timer?
    private var dismissWorkItem: DispatchWorkItem?

    // MARK: - Initialization

    private init() {}

    deinit {
        dismissWorkItem?.cancel()
        trackingTimer?.invalidate()
        if Thread.isMainThread {
            overlayWindow?.close()
        } else {
            let window = overlayWindow
            DispatchQueue.main.async {
                window?.close()
            }
        }
    }

    // MARK: - Public Methods

    /// Show large cursor overlay
    /// - Parameters:
    ///   - color: Color for the cursor (default: white with black outline)
    ///   - duration: How long to show (default: 5 seconds)
    func showLargeCursor(color: NSColor? = nil, duration: TimeInterval? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.showLargeCursor(color: color, duration: duration)
            }
            return
        }

        logger.debug("Showing large cursor")

        // Dismiss any existing
        dismiss()

        let effectiveColor = color ?? cursorColor
        let effectiveDuration = duration ?? displayDuration

        // Get cursor position
        let mouseLocation = NSEvent.mouseLocation
        let cursorSize: CGFloat = 64 * sizeMultiplier / 3  // Base cursor ~64pt at 3x

        // Create overlay window (larger to accommodate the cursor visual)
        let windowSize = cursorSize * 2
        let windowRect = NSRect(
            x: mouseLocation.x - cursorSize / 2,
            y: mouseLocation.y - cursorSize / 2,
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
        window.isReleasedWhenClosed = false

        let cursorView = LargeCursorView(frame: NSRect(origin: .zero, size: windowRect.size))
        cursorView.cursorColor = effectiveColor
        cursorView.cursorSize = cursorSize
        window.contentView = cursorView

        window.orderFrontRegardless()
        overlayWindow = window

        // Follow cursor
        trackingTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,  // 60 FPS
            repeats: true
        ) { [weak self] timer in
            guard let self = self, let window = self.overlayWindow else {
                timer.invalidate()
                return
            }

            let currentLocation = NSEvent.mouseLocation
            let newOrigin = NSPoint(
                x: currentLocation.x - cursorSize / 2,
                y: currentLocation.y - cursorSize / 2
            )
            window.setFrameOrigin(newOrigin)
        }

        // Auto-dismiss
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + effectiveDuration,
            execute: workItem
        )
    }

    /// Hide the large cursor immediately
    func dismiss() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.dismiss()
            }
            return
        }

        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        trackingTimer?.invalidate()
        trackingTimer = nil

        if let window = overlayWindow {
            window.orderOut(nil)
            overlayWindow = nil
        }

        logger.debug("Large cursor dismissed")
    }
}

// MARK: - Large Cursor View

/// Custom view drawing a large arrow cursor
final class LargeCursorView: NSView {

    var cursorColor: NSColor = .white
    var cursorSize: CGFloat = 64

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw a large arrow cursor shape
        let scale = cursorSize / 24  // Base cursor is ~24pt

        // Arrow cursor path (standard macOS arrow shape)
        let path = NSBezierPath()

        // Starting from top-left (the point of the arrow)
        let offsetX = bounds.midX - cursorSize / 2
        let offsetY = bounds.midY + cursorSize / 2

        path.move(to: NSPoint(x: offsetX, y: offsetY))  // Top point
        path.line(to: NSPoint(x: offsetX, y: offsetY - 20 * scale))  // Down left edge
        path.line(to: NSPoint(x: offsetX + 4 * scale, y: offsetY - 16 * scale))  // Notch
        path.line(to: NSPoint(x: offsetX + 8 * scale, y: offsetY - 24 * scale))  // Bottom of tail
        path.line(to: NSPoint(x: offsetX + 12 * scale, y: offsetY - 22 * scale))  // Right of tail
        path.line(to: NSPoint(x: offsetX + 8 * scale, y: offsetY - 14 * scale))  // Back up
        path.line(to: NSPoint(x: offsetX + 14 * scale, y: offsetY - 14 * scale))  // Right edge
        path.close()

        // Draw shadow/outline
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 2, height: -2),
            blur: 4,
            color: NSColor.black.withAlphaComponent(0.5).cgColor
        )

        // Fill with white
        cursorColor.setFill()
        path.fill()

        // Black outline
        NSColor.black.setStroke()
        path.lineWidth = 1.5 * scale
        path.stroke()

        context.restoreGState()
    }
}
