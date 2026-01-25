//
//  Color+Hex.swift
//  MouseOn
//
//  Extension for converting between Color and hex strings.
//

import SwiftUI
import AppKit

// MARK: - Color Hex Extension

extension Color {
    
    /// Initialize a Color from a hex string
    /// Supported formats:
    /// - 3-digit RGB: "#FFF" or "FFF" (expands to #FFFFFF)
    /// - 6-digit RGB: "#FF5733" or "FF5733"
    /// - 8-digit RGBA: "#FF573380" or "FF573380" (last 2 digits are alpha)
    /// - Parameter hex: The hex color string
    /// - Returns: A Color if the hex string is valid, nil otherwise
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        // Validate length: must be 3, 6, or 8 characters
        guard [3, 6, 8].contains(hexSanitized.count) else { return nil }
        
        // Validate all characters are valid hex digits (0-9, A-F, a-f)
        let validHexCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard hexSanitized.unicodeScalars.allSatisfy({ validHexCharacters.contains($0) }) else { return nil }
        
        // Expand 3-digit shorthand (#RGB -> #RRGGBB)
        if hexSanitized.count == 3 {
            hexSanitized = hexSanitized.map { "\($0)\($0)" }.joined()
        }
        
        var hexValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&hexValue) else { return nil }
        
        let r: Double
        let g: Double
        let b: Double
        let a: Double
        
        if hexSanitized.count == 8 {
            // 8-digit RGBA format
            r = Double((hexValue & 0xFF000000) >> 24) / 255.0
            g = Double((hexValue & 0x00FF0000) >> 16) / 255.0
            b = Double((hexValue & 0x0000FF00) >> 8) / 255.0
            a = Double(hexValue & 0x000000FF) / 255.0
        } else {
            // 6-digit RGB format (after potential expansion from 3-digit)
            r = Double((hexValue & 0xFF0000) >> 16) / 255.0
            g = Double((hexValue & 0x00FF00) >> 8) / 255.0
            b = Double(hexValue & 0x0000FF) / 255.0
            a = 1.0
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Convert a Color to its hex string representation
    /// - Parameter includeAlpha: If true, outputs 8-digit RGBA format when alpha < 1.0
    /// - Returns: A hex string (e.g., "#FF5733" or "#FF573380") or nil if conversion fails
    func toHex(includeAlpha: Bool = false) -> String? {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        
        if includeAlpha && components.alphaComponent < 1.0 {
            let a = Int(components.alphaComponent * 255)
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
