//
//  PageSwipeConfiguration.swift
//  PageSwipeKit
//
//  Created by stoyan on 23.02.26.
//

import UIKit

// MARK: - PageSwipeConfiguration

/// Configuration for page swipe behavior and appearance.
public struct PageSwipeConfiguration: Sendable {
    
    // MARK: - Properties
    
    /// How pages should scale during transitions. Default: .uniform
    public var scalingBehavior: ScalingBehavior
    
    /// Scale factor applied to pages during transitions (0.0-1.0). Default: 0.92
    /// For uniform scaling, all pages use this scale.
    /// For progressive scaling, this is the minimum scale for off-center pages.
    public var transitionScale: CGFloat
    
    /// Base corner radius for pages. Adjusts concentrically during scaling. Default: 44
    public var cornerRadius: CGFloat
    
    /// Minimum swipe velocity (pts/sec) to trigger page change. Default: 300
    public var velocityThreshold: CGFloat
    
    /// Duration of the scale-down animation when dragging begins. Default: 0.15
    /// Pages stay touchable throughout; a drag that begins mid-animation interrupts it
    /// and the next transition continues from the on-screen state.
    public var scaleDownDuration: TimeInterval
    
    /// Duration of the spring animation when restoring scale. Default: 0.35
    /// Pages stay touchable throughout; a drag that begins mid-animation interrupts it
    /// and the next transition continues from the on-screen state.
    public var restoreDuration: TimeInterval
    
    /// Spring damping ratio for restore animation (0.0-1.0). Default: 0.8
    public var springDamping: CGFloat
    
    // MARK: - Initialization
    
    public init(
        scalingBehavior: ScalingBehavior = .uniform,
        transitionScale: CGFloat = 0.92,
        cornerRadius: CGFloat = 44,
        velocityThreshold: CGFloat = 300,
        scaleDownDuration: TimeInterval = 0.15,
        restoreDuration: TimeInterval = 0.35,
        springDamping: CGFloat = 0.8
    ) {
        self.scalingBehavior = scalingBehavior
        self.transitionScale = transitionScale
        self.cornerRadius = cornerRadius
        self.velocityThreshold = velocityThreshold
        self.scaleDownDuration = scaleDownDuration
        self.restoreDuration = restoreDuration
        self.springDamping = springDamping
    }
}

// MARK: - Static Presets

extension PageSwipeConfiguration {
    
    /// Creates a configuration with default values.
    public static var `default`: PageSwipeConfiguration {
        PageSwipeConfiguration()
    }
    
    /// Configuration with no scaling effect.
    public static var noScale: PageSwipeConfiguration {
        PageSwipeConfiguration(
            scalingBehavior: .none,
            transitionScale: 1.0
        )
    }
    
    /// Configuration with progressive scaling - pages scale based on distance from center.
    public static var progressive: PageSwipeConfiguration {
        PageSwipeConfiguration(scalingBehavior: .progressive)
    }
}
