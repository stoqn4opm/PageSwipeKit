//
//  PageSwipeConfiguration.swift
//  PageSwipeKit
//
//  Created by stoyan on 20.02.26.
//

import SwiftUI

/// Configuration for the PageSwipeView behavior and appearance.
public struct PageSwipeConfiguration {
    
    // MARK: - Presets
    
    /// Default configuration with uniform scaling.
    nonisolated(unsafe) public static let `default` = PageSwipeConfiguration()
    
    /// Configuration without scaling - pages slide without shrinking.
    nonisolated(unsafe) public static let noScale = PageSwipeConfiguration(scalingBehavior: .none)
    
    /// Configuration with progressive scaling - pages scale based on distance from center.
    nonisolated(unsafe) public static let progressive = PageSwipeConfiguration(scalingBehavior: .progressive)
    
    // MARK: - Properties
    
    /// The corner radius of pages. Defaults to device screen corner radius approximation.
    public var cornerRadius: CGFloat
    
    /// The gap between pages during transition (in points).
    public var pageGap: CGFloat
    
    /// How pages should scale during transitions.
    public var scalingBehavior: ScalingBehavior
    
    /// The scale factor applied to pages during transition (0.0 to 1.0).
    /// For uniform scaling, all pages use this scale.
    /// For progressive scaling, this is the minimum scale for off-center pages.
    public var transitionScale: CGFloat
    
    /// Velocity threshold to trigger page change even if drag distance is small.
    public var velocityThreshold: CGFloat
    
    /// Animation used for snapping to pages.
    public var snapAnimation: Animation
    
    /// Rubber band resistance factor (0.0 = no resistance, 1.0 = full resistance).
    public var rubberBandResistance: CGFloat
    
    // MARK: - Initialization
    
    public init(
        cornerRadius: CGFloat = 64,
        pageGap: CGFloat = 8,
        scalingBehavior: ScalingBehavior = .uniform,
        transitionScale: CGFloat = 0.92,
        velocityThreshold: CGFloat = 300,
        snapAnimation: Animation = .interpolatingSpring(stiffness: 300, damping: 30),
        rubberBandResistance: CGFloat = 0.55
    ) {
        self.cornerRadius = cornerRadius
        self.pageGap = pageGap
        self.scalingBehavior = scalingBehavior
        self.transitionScale = transitionScale
        self.velocityThreshold = velocityThreshold
        self.snapAnimation = snapAnimation
        self.rubberBandResistance = rubberBandResistance
    }
}
