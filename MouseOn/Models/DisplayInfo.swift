//
//  DisplayInfo.swift
//  MouseOn
//
//  Model representing information about a connected display.
//

import Foundation
import CoreGraphics

// MARK: - Display Info

/// Represents a connected display with its properties and state
///
/// Conforms to:
/// - `Identifiable`: For use in SwiftUI lists and ForEach
/// - `Equatable`: For comparison and detecting changes
/// - `Hashable`: For use in Sets and as Dictionary keys
struct DisplayInfo: Identifiable, Equatable, Hashable {
    /// Unique display identifier from CoreGraphics
    let id: CGDirectDisplayID
    
    /// Display name (from system or alias)
    let name: String
    
    /// Display frame in screen coordinates
    let frame: CGRect
    
    /// Whether this is the built-in display (MacBook screen)
    let isBuiltin: Bool
    
    /// Whether this is the main display
    let isMain: Bool
    
    /// Display vendor ID (Apple = 0x610 or 1552)
    let vendorID: UInt32
    
    /// Display model ID
    let modelID: UInt32
    
    /// Whether this display is likely a Sidecar connection
    let isSidecarGuess: Bool
    
    /// Whether the mouse cursor is currently on this display
    let isCurrentMouse: Bool
    
    /// Whether this display is in a mirror set
    let isMirrored: Bool
    
    /// Whether this display is active (drawable)
    let isActive: Bool
    
    /// Whether this display is online
    let isOnline: Bool
}

// MARK: - Display Detection Utilities

extension DisplayInfo {
    
    /// Check if vendor and model IDs suggest a Sidecar display
    /// - Parameters:
    ///   - vendorID: The display vendor ID
    ///   - modelID: The display model ID
    ///   - isBuiltin: Whether the display is built-in
    /// - Returns: True if the display is likely Sidecar
    static func isSidecarDisplay(
        vendorID: UInt32,
        modelID: UInt32,
        isBuiltin: Bool
    ) -> Bool {
        guard !isBuiltin else { return false }
        
        let isAppleVendor = Constants.Display.appleVendorIDs.contains(vendorID)
        let isVirtualModel = modelID == 0 || modelID >= Constants.Display.virtualModelThreshold
        
        return isAppleVendor && isVirtualModel
    }
    
    /// Check if a display name suggests Sidecar
    /// - Parameter name: The display name to check
    /// - Returns: True if the name contains Sidecar indicators
    static func nameHintsSidecar(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return lowercased.contains("sidecar") || lowercased.contains("ipad")
    }
}
