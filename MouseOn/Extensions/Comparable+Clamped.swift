//
//  Comparable+Clamped.swift
//  MouseOn
//
//  Extension for clamping values to a range.
//

import Foundation

// MARK: - Comparable Clamped Extension

extension Comparable {

    /// Clamp a value to a closed range
    /// - Parameter range: The range to clamp to
    /// - Returns: The value clamped to the range bounds
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
