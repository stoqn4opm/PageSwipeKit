//
//  TouchDeliveryDuringSettleTests.swift
//  PageSwipeKitTests
//
//  A page must stay touchable while the settle animation restores the cells:
//  a swipe that lands during that animation is the user's next page change,
//  not something to swallow until the spring is done.
//

import Testing
import UIKit
@testable import PageSwipeKit

// MARK: - Test Helpers

/// Long animations so a probe 100 ms in sits deep inside the window, never at its edge.
let settleConfiguration = PageSwipeConfiguration(restoreDuration: 2)
let progressiveSettleConfiguration = PageSwipeConfiguration(scalingBehavior: .progressive, cornerRadius: 55, restoreDuration: 2)

/// Builds a loaded controller in a window and returns the window alongside. The
/// test must keep it alive: a released window means no animation ever runs and
/// every "during the animation" assertion passes vacuously.
@MainActor
func createLoadedController(configuration: PageSwipeConfiguration) -> (PageSwipeViewController, UIWindow) {
    let pages = (0..<3).map { _ in SwipePage(viewController: UIViewController()) }
    let controller = PageSwipeViewController(pages: pages, configuration: configuration)

    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.loadViewIfNeeded()
    controller.view.layoutIfNeeded()

    return (controller, window)
}

@MainActor
func pagingCollectionView(of controller: PageSwipeViewController) -> UICollectionView {
    controller.view.subviews.compactMap { $0 as? UICollectionView }.first!
}

@MainActor
func wait(milliseconds: UInt64) async throws {
    try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
}

@MainActor
func hasScaleAnimation(in collectionView: UICollectionView) -> Bool {
    collectionView.visibleCells.contains { cell in
        (cell.layer.animationKeys() ?? []).contains { $0.hasPrefix("transform") || $0.hasPrefix("cornerRadius") }
    }
}

@MainActor
private func isInside(_ pageView: UIView, _ hit: UIView?) -> Bool {
    guard let hit else { return false }
    return hit === pageView || hit.isDescendant(of: pageView)
}

private let pageCentre = CGPoint(x: 187, y: 400)

// MARK: - Touch Delivery During Settle Tests

@Suite("Touch Delivery During Settle", .serialized)
struct TouchDeliveryDuringSettleTests {

    @Test("Uniform scaling: the page is hit-testable while the restore animation runs")
    @MainActor
    func pageIsHitTestableDuringRestoreUniform() async throws {
        // Given
        let (sut, window) = createLoadedController(configuration: settleConfiguration)
        defer { withExtendedLifetime(window) {} }
        let scrollView = pagingCollectionView(of: sut)
        let pageView = sut.pages[0].viewController.view!

        // When: the pages scale down for a drag, settle, and the restore spring is in flight
        sut.scrollViewWillBeginDragging(scrollView)
        try await wait(milliseconds: 300)
        sut.scrollViewDidEndDecelerating(scrollView)
        try await wait(milliseconds: 100)

        // Then
        let hit = window.hitTest(pageCentre, with: nil)
        #expect(isInside(pageView, hit), "hitTest resolved to \(String(describing: hit)) instead of the page")
    }

    @Test("Progressive scaling: the page is hit-testable while the restore animation runs")
    @MainActor
    func pageIsHitTestableDuringRestoreProgressive() async throws {
        // Given
        let (sut, window) = createLoadedController(configuration: progressiveSettleConfiguration)
        defer { withExtendedLifetime(window) {} }
        let scrollView = pagingCollectionView(of: sut)
        let pageView = sut.pages[0].viewController.view!

        // When: a scroll tick gives the centred cell its concentric corner radius, the page
        // settles, and the restore spring animating that radius is in flight
        sut.scrollViewWillBeginDragging(scrollView)
        sut.scrollViewDidScroll(scrollView)
        try await wait(milliseconds: 50)
        sut.scrollViewDidEndDecelerating(scrollView)
        try await wait(milliseconds: 100)

        // Then
        let hit = window.hitTest(pageCentre, with: nil)
        #expect(isInside(pageView, hit), "hitTest resolved to \(String(describing: hit)) instead of the page")
    }
}
