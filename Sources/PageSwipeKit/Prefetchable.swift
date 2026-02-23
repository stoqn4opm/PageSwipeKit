//
//  Prefetchable.swift
//  PageSwipeKit
//
//  Created by stoyan on 23.02.26.
//

import Foundation

// MARK: - Prefetchable

/// Protocol for objects that support prefetching their data.
/// Implement this to load data before the page becomes visible.
public protocol Prefetchable: AnyObject {
    
    /// Called when the page should prefetch its data.
    /// Implement this to load data before the page becomes visible.
    func prefetchData()
}
