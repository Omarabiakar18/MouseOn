//
//  CursorHighlighter.swift
//  MouseOn
//
//  Provides animated cursor highlight for "Find My Cursor" feature.
//

import AppKit
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.mouseon.app", category: "CursorHighlighter")

// MARK: - Cursor Highlighter

/// Manages cursor highlight overlay for finding the cursor
final class CursorHighlighter {

    // MARK: - Shared Instance

    static let shared = CursorHighlighter()

    // MARK: - Private Properties

    private var overlayWindow: NSWindow?
    private var animationTimer: Timer?
    private var animationPhase: CGFloat = 0
    private var dismissWorkItem: DispatchWorkItem?

    // MARK: - Initialization

    private init() {}

    deinit {
        // Cancel work item and timer - these are thread-safe operations
        dismissWorkItem?.cancel()
        animationTimer?.invalidate()

        // Window cleanup must happen on main thread
        // Use async to avoid potential deadlock if deinit is called from main thread
        // while main thread is waiting on something else
        if Thread.isMainThread {
            overlayWindow?.close()
        } else {
            // Capture window reference before async to avoid accessing self
            let window = overlayWindow
            DispatchQueue.main.async {
                window?.close()
            }
        }
    }

    // MARK: - Public Methods

    /// Show animated highlight around cursor
    /// - Parameter color: The color for the highlight animation
    func highlight(color: NSColor = .systemOrange) {
        // Ensure we're on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.highlight(color: color)
            }
            return
        }

        logger.debug("Showing cursor highlight")

        // Announce to VoiceOver users
        Task { @MainActor in
            AccessibilityAnnouncer.shared.announceFindCursor()
        }

        // Remove any existing overlay
        dismiss()

        // Get cursor position
        let mouseLocation = NSEvent.mouseLocation
        let windowSize = Constants.UserInterface.highlightWindowSize

        // Create overlay window
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
        window.isReleasedWhenClosed = false

        let highlightView = CursorHighlightView(frame: NSRect(origin: .zero, size: windowRect.size))
        highlightView.highlightColor = color
        window.contentView = highlightView

        window.orderFrontRegardless()
        overlayWindow = window

        // Animate and follow cursor
        animationPhase = 0
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Timing.highlightAnimationInterval,
            repeats: true
        ) { [weak self] timer in
            guard let self = self, let window = self.overlayWindow else {
                timer.invalidate()
                return
            }

            // Update animation phase
            self.animationPhase += 0.05
            if let view = window.contentView as? CursorHighlightView {
                view.phase = self.animationPhase
                view.needsDisplay = true
            }

            // Follow the cursor
            let currentLocation = NSEvent.mouseLocation
            let newOrigin = NSPoint(
                x: currentLocation.x - windowSize / 2,
                y: currentLocation.y - windowSize / 2
            )
            window.setFrameOrigin(newOrigin)
        }

        // Auto-dismiss after delay
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.Timing.highlightDismissDelay,
            execute: workItem
        )
    }

    // MARK: - Private Methods

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

        logger.debug("Cursor highlight dismissed")
    }
}

// MARK: - Cursor Highlight View

/// Custom view for drawing animated circles around cursor
final class CursorHighlightView: NSView {

    var phase: CGFloat = 0
    var highlightColor: NSColor = .systemOrange

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxRadius = min(bounds.width, bounds.height) / 2

        // Draw multiple expanding circles
        for i in 0..<Constants.UserInterface.highlightCircleCount {
            let offset = CGFloat(i) * 0.33
            let progress = (phase + offset).truncatingRemainder(dividingBy: 1.0)
            let radius = maxRadius * progress
            let alpha = 1.0 - progress

            context.setStrokeColor(highlightColor.withAlphaComponent(alpha * 0.8).cgColor)
            context.setLineWidth(Constants.UserInterface.highlightLineWidth)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.strokePath()
        }

        // Draw center dot
        context.setFillColor(highlightColor.cgColor)
        context.addArc(
            center: center,
            radius: Constants.UserInterface.highlightCenterDotRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )
        context.fillPath()
    }
}
