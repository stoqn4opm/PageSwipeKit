//
//  SwipePage.swift
//  PageSwipeKit
//
//  Created by stoyan on 23.02.26.
//

import UIKit
import SwiftUI

// MARK: - SwipePage

/// A page for the PageSwipeViewController that bundles a view controller with its prefetchable.
public struct SwipePage: Identifiable {
    
    // MARK: - Properties
    
    public let id: UUID
    public let viewController: UIViewController
    public let prefetchable: Prefetchable?
    
    // MARK: - Initialization
    
    public init(
        pageId: UUID = UUID(),
        viewController: UIViewController,
        prefetchable: Prefetchable? = nil
    ) {
        self.id = pageId
        self.viewController = viewController
        self.prefetchable = prefetchable
    }
    
    /// Creates a SwipePage from a SwiftUI view and its view model.
    @MainActor
    public init<V: View, P: Prefetchable>(
        pageId: UUID = UUID(),
        view: V,
        prefetchable: P
    ) {
        self.id = pageId
        self.viewController = UIHostingController(rootView: view)
        self.prefetchable = prefetchable
    }
}
