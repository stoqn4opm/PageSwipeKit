//
//  ScalingBehavior.swift
//  PageSwipeKit
//
//  Created by stoyan on 20.02.26.
//

import Foundation

/// Defines how pages scale during transitions.
public enum ScalingBehavior: Hashable {
    /// No scaling - pages remain full size during transitions.
    case none
    
    /// All pages scale uniformly when dragging begins, and scale back when settled.
    case uniform
    
    /// Pages scale based on their distance from center - further pages appear smaller.
    case progressive
}
