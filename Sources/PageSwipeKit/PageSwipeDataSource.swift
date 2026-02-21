//
//  PageSwipeDataSource.swift
//  PageSwipeKit
//
//  Created by stoyan on 20.02.26.
//

import SwiftUI
import Combine

/// A data source that manages a dynamic collection of pages for PageSwipeView.
/// Supports appending and prepending pages while maintaining correct current page position.
@MainActor
public final class PageSwipeDataSource<PageID: Hashable>: ObservableObject {
    
    // MARK: - Properties
    
    /// The ordered collection of page identifiers.
    @Published public private(set) var pageIDs: [PageID] = []
    
    /// The current page index. Automatically adjusted when prepending pages.
    @Published public var currentPageIndex: Int = 0
    
    /// Callback when a page becomes a neighbor (for pre-fetching).
    public var onPageBecameNeighbor: ((PageID) -> Void)?
    
    /// Callback when scrolling begins (user starts dragging).
    public var onScrollBegan: (() -> Void)?
    
    /// Callback when scrolling ends (page has settled).
    public var onScrollEnded: (() -> Void)?
    
    /// Whether the view is currently being scrolled.
    @Published public private(set) var isScrolling: Bool = false
    
    /// The current page identifier.
    public var currentPageID: PageID? {
        guard currentPageIndex >= 0 && currentPageIndex < pageIDs.count else { return nil }
        return pageIDs[currentPageIndex]
    }
    
    /// The number of pages.
    public var pageCount: Int {
        pageIDs.count
    }
    
    // MARK: - Initialization
    
    public init(initialPages: [PageID] = [], initialIndex: Int = 0) {
        self.pageIDs = initialPages
        self.currentPageIndex = min(initialIndex, max(0, initialPages.count - 1))
    }
    
    // MARK: - Page Management
    
    /// Appends pages to the end of the collection.
    /// - Parameter pages: The page identifiers to append.
    public func append(_ pages: [PageID]) {
        pageIDs.append(contentsOf: pages)
    }
    
    /// Appends a single page to the end of the collection.
    /// - Parameter page: The page identifier to append.
    public func append(_ page: PageID) {
        pageIDs.append(page)
    }
    
    /// Prepends pages to the beginning of the collection.
    /// Automatically adjusts currentPageIndex to maintain the same visible page.
    /// - Parameter pages: The page identifiers to prepend.
    public func prepend(_ pages: [PageID]) {
        guard !pages.isEmpty else { return }
        pageIDs.insert(contentsOf: pages, at: 0)
        currentPageIndex += pages.count
    }
    
    /// Prepends a single page to the beginning of the collection.
    /// Automatically adjusts currentPageIndex to maintain the same visible page.
    /// - Parameter page: The page identifier to prepend.
    public func prepend(_ page: PageID) {
        pageIDs.insert(page, at: 0)
        currentPageIndex += 1
    }
    
    /// Removes a page at the specified index.
    /// - Parameter index: The index of the page to remove.
    public func remove(at index: Int) {
        guard index >= 0 && index < pageIDs.count else { return }
        pageIDs.remove(at: index)
        
        if currentPageIndex >= pageIDs.count {
            currentPageIndex = max(0, pageIDs.count - 1)
        } else if index < currentPageIndex {
            currentPageIndex -= 1
        }
    }
    
    /// Removes pages with the specified identifiers.
    /// - Parameter pages: The page identifiers to remove.
    public func remove(_ pages: [PageID]) {
        for page in pages {
            if let index = pageIDs.firstIndex(of: page) {
                remove(at: index)
            }
        }
    }
    
    /// Replaces all pages with a new collection.
    /// - Parameters:
    ///   - pages: The new page identifiers.
    ///   - resetIndex: If true, resets currentPageIndex to 0. If false, attempts to maintain position.
    public func replaceAll(with pages: [PageID], resetIndex: Bool = true) {
        pageIDs = pages
        if resetIndex || currentPageIndex >= pages.count {
            currentPageIndex = 0
        }
    }
    
    /// Navigates to a specific page by index.
    /// - Parameters:
    ///   - index: The target page index.
    ///   - animated: Whether to animate the transition.
    ///   - animation: The animation to use (uses default snap animation if nil).
    public func navigateToIndex(_ index: Int, animated: Bool = true, animation: Animation? = nil) {
        guard index >= 0 && index < pageIDs.count else { return }
        
        if animated {
            withAnimation(animation ?? .interpolatingSpring(stiffness: 300, damping: 30)) {
                currentPageIndex = index
            }
        } else {
            currentPageIndex = index
        }
    }
    
    /// Navigates to a specific page by identifier.
    /// - Parameters:
    ///   - pageID: The target page identifier.
    ///   - animated: Whether to animate the transition.
    ///   - animation: The animation to use (uses default snap animation if nil).
    public func navigateToPage(_ pageID: PageID, animated: Bool = true, animation: Animation? = nil) {
        guard let index = pageIDs.firstIndex(of: pageID) else { return }
        navigateToIndex(index, animated: animated, animation: animation)
    }
    
    // MARK: - Internal
    
    func notifyNeighborPages() {
        guard let callback = onPageBecameNeighbor else { return }
        
        let count = pageIDs.count
        let index = currentPageIndex
        
        // Ensure index is valid before accessing neighbors
        guard index >= 0 && index < count else { return }
        
        if index > 0 {
            callback(pageIDs[index - 1])
        }
        if index < count - 1 {
            callback(pageIDs[index + 1])
        }
    }
    
    func notifyScrollBegan() {
        guard !isScrolling else { return }
        isScrolling = true
        onScrollBegan?()
    }
    
    func notifyScrollEnded() {
        guard isScrolling else { return }
        isScrolling = false
        onScrollEnded?()
    }
}
