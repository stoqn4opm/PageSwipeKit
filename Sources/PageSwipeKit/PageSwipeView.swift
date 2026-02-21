//
//  PageSwipeView.swift
//  PageSwipeKit
//
//  Created by stoyan on 20.02.26.
//

import SwiftUI

/// A SwiftUI view that mimics the iOS app switcher page swiping behavior.
///
/// Features:
/// - Interactive drag gesture with velocity-based snapping
/// - Concentric corner radius alignment during transitions
/// - Scale animation (full-screen when settled, scaled during transition)
/// - Rubber-band bounce at edges
/// - Dynamic page management via PageSwipeDataSource
/// - Pre-fetching callback for neighbor pages
/// - Configurable programmatic navigation
public struct PageSwipeView<PageID: Hashable, PageContent: View>: View {
    
    // MARK: - Properties
    
    /// The data source managing the page collection.
    @ObservedObject var dataSource: PageSwipeDataSource<PageID>
    
    /// Closure that builds the view for a given page identifier.
    let pageContent: (PageID) -> PageContent
    
    /// Configuration for appearance and behavior.
    let configuration: PageSwipeConfiguration
    
    // MARK: - State
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isScaledDown: Bool = false
    @GestureState private var dragState: DragState = .inactive
    
    // MARK: - Initialization
    
    public init(
        dataSource: PageSwipeDataSource<PageID>,
        configuration: PageSwipeConfiguration = .default,
        @ViewBuilder pageContent: @escaping (PageID) -> PageContent
    ) {
        self.dataSource = dataSource
        self.configuration = configuration
        self.pageContent = pageContent
    }
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let currentIndex = dataSource.currentPageIndex
            let pageIDs = dataSource.pageIDs
            let totalOffset = -CGFloat(currentIndex) * screenWidth + dragOffset
            
            ZStack {
                ForEach(visiblePages(currentIndex: currentIndex, pageIDs: pageIDs)) { item in
                    pageView(
                        for: item.index,
                        pageID: item.pageID,
                        currentIndex: currentIndex,
                        screenWidth: screenWidth,
                        totalOffset: totalOffset,
                        geometry: geometry
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                pageSwipeGesture(screenWidth: screenWidth)
            )
            .onChange(of: dragState.isActive) { [isDragging] newValue in
                // Detect gesture cancellation (e.g., second finger touch)
                // When dragState becomes inactive but isDragging is still true,
                // it means the gesture was cancelled
                if !newValue && isDragging {
                    handleGestureCancelled(screenWidth: screenWidth)
                }
            }
            .onChange(of: dataSource.currentPageIndex) { _ in
                dataSource.notifyNeighborPages()
            }
            .onAppear {
                dataSource.notifyNeighborPages()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Drag State

extension PageSwipeView {
    
    private enum DragState {
        case inactive
        case dragging(translation: CGFloat, startLocation: CGPoint)
        
        var translation: CGFloat {
            switch self {
            case .inactive:
                return 0
            case .dragging(let translation, _):
                return translation
            }
        }
        
        var isActive: Bool {
            switch self {
            case .inactive:
                return false
            case .dragging:
                return true
            }
        }
        
        var startLocation: CGPoint? {
            switch self {
            case .inactive:
                return nil
            case .dragging(_, let location):
                return location
            }
        }
    }
}

// MARK: - Page View Construction

extension PageSwipeView {
    
    private struct VisiblePage: Identifiable {
        let index: Int
        let pageID: PageID
        
        // Use pageID for identity to handle prepend/append correctly
        var id: AnyHashable { AnyHashable(pageID) }
    }
    
    private func visiblePages(currentIndex: Int, pageIDs: [PageID]) -> [VisiblePage] {
        let pageCount = pageIDs.count
        guard pageCount > 0 else { return [] }
        
        // Clamp current index to valid range
        let safeCurrentIndex = min(max(0, currentIndex), pageCount - 1)
        
        let minIndex = max(0, safeCurrentIndex - 1)
        let maxIndex = min(pageCount - 1, safeCurrentIndex + 1)
        
        return (minIndex...maxIndex).map { index in
            VisiblePage(index: index, pageID: pageIDs[index])
        }
    }
    
    private func pageView(
        for index: Int,
        pageID: PageID,
        currentIndex: Int,
        screenWidth: CGFloat,
        totalOffset: CGFloat,
        geometry: GeometryProxy
    ) -> some View {
        let pageOffset = CGFloat(index) * screenWidth + totalOffset
        let normalizedOffset = pageOffset / screenWidth
        
        let scale = calculateScale(normalizedOffset: normalizedOffset)
        
        // When scaling is active, use minimal gap since scaling already creates visual separation
        let isScaling = configuration.scalingBehavior != .none && 
            (configuration.scalingBehavior == .progressive || isScaledDown)
        let effectiveGap = isScaling ? configuration.pageGap * 0.1 : configuration.pageGap
        let gapOffset = normalizedOffset * effectiveGap
        let cornerRadius = calculateCornerRadius(scale: scale, screenWidth: screenWidth)
        
        return pageContent(pageID)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(scale)
            .offset(x: pageOffset + gapOffset)
            .zIndex(index == currentIndex ? 1 : 0)
    }
    
    private func calculateScale(normalizedOffset: CGFloat) -> CGFloat {
        switch configuration.scalingBehavior {
        case .none:
            return 1.0
            
        case .uniform:
            return isScaledDown ? configuration.transitionScale : 1.0
            
        case .progressive:
            // Scale based on distance from center (0 = centered, 1 = one page away)
            let distance = abs(normalizedOffset)
            // Interpolate from 1.0 (centered) to transitionScale (one page away)
            let scale = interpolate(from: 1.0, to: configuration.transitionScale, progress: min(distance, 1.0))
            return scale
        }
    }
    
    private func calculateCornerRadius(scale: CGFloat, screenWidth: CGFloat) -> CGFloat {
        // Calculate concentric corner radius
        // When scaled down, the corner radius should increase to maintain visual concentricity
        // with the device screen corners
        let deviceCornerRadius = configuration.cornerRadius
        let scaledWidth = screenWidth * scale
        let inset = (screenWidth - scaledWidth) / 2
        
        // The inner corner radius needs to be adjusted so that when we add the inset,
        // we get the same visual arc as the device corner
        let concentricRadius = max(0, deviceCornerRadius - inset)
        return concentricRadius / scale
    }
    
    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}

// MARK: - Gesture Handling

extension PageSwipeView {
    
    private func pageSwipeGesture(screenWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($dragState) { value, state, _ in
                state = .dragging(translation: value.translation.width, startLocation: value.startLocation)
            }
            .onChanged { value in
                handleDragChanged(value: value, screenWidth: screenWidth)
            }
            .onEnded { value in
                handleDragEnded(value: value, screenWidth: screenWidth)
            }
    }
    
    private func handleDragChanged(value: DragGesture.Value, screenWidth: CGFloat) {
        // Notify scroll began and scale down on first drag change
        if !isDragging {
            dataSource.notifyScrollBegan()
            // Only animate scale for uniform mode (progressive scales continuously)
            if configuration.scalingBehavior == .uniform {
                withAnimation(.easeOut(duration: 0.15)) {
                    isScaledDown = true
                }
            }
        }
        
        isDragging = true
        
        var translation = value.translation.width
        
        // Apply rubber band effect at edges
        let isAtFirstPage = dataSource.currentPageIndex == 0 && translation > 0
        let isAtLastPage = dataSource.currentPageIndex == dataSource.pageCount - 1 && translation < 0
        
        if isAtFirstPage || isAtLastPage {
            translation = rubberBandClamp(translation)
        }
        
        dragOffset = translation
    }
    
    private func handleDragEnded(value: DragGesture.Value, screenWidth: CGFloat) {
        // If we weren't actively dragging (gesture was filtered out), just reset
        guard isDragging else {
            dragOffset = 0
            return
        }
        
        let translation = value.translation.width
        let velocity = value.velocity.width
        let threshold = screenWidth / 2
        
        var targetPage = dataSource.currentPageIndex
        
        // Determine target page based on velocity and position
        if abs(velocity) > configuration.velocityThreshold {
            // Velocity-based decision
            if velocity < 0 && dataSource.currentPageIndex < dataSource.pageCount - 1 {
                targetPage = dataSource.currentPageIndex + 1
            } else if velocity > 0 && dataSource.currentPageIndex > 0 {
                targetPage = dataSource.currentPageIndex - 1
            }
        } else {
            // Position-based decision
            if translation < -threshold && dataSource.currentPageIndex < dataSource.pageCount - 1 {
                targetPage = dataSource.currentPageIndex + 1
            } else if translation > threshold && dataSource.currentPageIndex > 0 {
                targetPage = dataSource.currentPageIndex - 1
            }
        }
        
        // Animate to target page
        withAnimation(configuration.snapAnimation) {
            dataSource.currentPageIndex = targetPage
            dragOffset = 0
            isDragging = false
            isScaledDown = false
        }
        
        // Notify scroll ended after animation completes (approximate duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dataSource.notifyScrollEnded()
        }
    }
    
    private func handleGestureCancelled(screenWidth: CGFloat) {
        // Snap back to current page when gesture is cancelled (e.g., second finger touch)
        let threshold = screenWidth / 2
        var targetPage = dataSource.currentPageIndex
        
        // Determine if we should go to adjacent page based on current drag offset
        if dragOffset < -threshold && dataSource.currentPageIndex < dataSource.pageCount - 1 {
            targetPage = dataSource.currentPageIndex + 1
        } else if dragOffset > threshold && dataSource.currentPageIndex > 0 {
            targetPage = dataSource.currentPageIndex - 1
        }
        
        withAnimation(configuration.snapAnimation) {
            dataSource.currentPageIndex = targetPage
            dragOffset = 0
            isDragging = false
            isScaledDown = false
        }
        
        // Notify scroll ended after animation completes (approximate duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dataSource.notifyScrollEnded()
        }
    }
    
    private func rubberBandClamp(_ offset: CGFloat) -> CGFloat {
        let resistance = configuration.rubberBandResistance
        let absOffset = abs(offset)
        let sign: CGFloat = offset >= 0 ? 1 : -1
        
        // Rubber band formula: x * (1 - resistance * (x / maxStretch))
        let maxStretch: CGFloat = 200
        let dampedOffset = absOffset * (1 - resistance * min(1, absOffset / maxStretch))
        
        return sign * dampedOffset
    }
}
