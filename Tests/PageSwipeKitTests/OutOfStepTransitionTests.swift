//
//  OutOfStepTransitionTests.swift
//  PageSwipeKitTests
//
//  A size transition does not always end after the bounds change it
//  announces. A screen that is off screen when it is told about an unfold
//  ends the transition at its folded size and gets the unfolded size only
//  once it is back in the window; a resized window can end the transition
//  while the new size is still pending, so the re-snap's own layout pass
//  applies it. Either way the pages must end up at the new size, on the
//  current page, with no neighbour in view.
//

import Testing
import UIKit
@testable import PageSwipeKit

// MARK: - Test Helpers

/// The detail column folded and unfolded in a phone's window, as measured:
/// the unfold widens the column and also changes its height.
private let foldedColumnSize = CGSize(width: 466, height: 678)
private let unfoldedColumnSize = CGSize(width: 575, height: 669)
/// The unfolded column after its window is dragged wider: only the width
/// changes.
private let widenedColumnSize = CGSize(width: 818, height: 669)

/// Resizes the column, its width through the column and its height through
/// the window, without running a layout pass.
@MainActor
private func setColumnSize(_ size: CGSize, of host: ColumnHostViewController, in window: UIWindow) {
    host.setColumnWidth(size.width)
    window.frame = CGRect(origin: .zero, size: CGSize(width: window.frame.width, height: size.height))
}

/// Builds a controller with five pages in a column of `columnSize`, already
/// showing page 2. The window is returned so the test keeps it alive.
@MainActor
private func createController(columnSize: CGSize) -> (PageSwipeViewController, ColumnHostViewController, UIWindow) {
    let (controller, host, window) = createColumnHostedController(showingPageAt: 2, columnWidth: columnSize.width)
    setColumnSize(columnSize, of: host, in: window)
    window.layoutIfNeeded()
    return (controller, host, window)
}

/// Resizes the column inside a size transition, in the order the system
/// usually keeps: announced, laid out at the new size, then ended.
@MainActor
private func resizeColumn(of controller: PageSwipeViewController,
                          in host: ColumnHostViewController,
                          window: UIWindow,
                          to size: CGSize) {
    let coordinator = MockTransitionCoordinator()
    controller.viewWillTransition(to: size, with: coordinator)
    setColumnSize(size, of: host, in: window)
    window.layoutIfNeeded()
    coordinator.finishTransition()
}

// MARK: - Out Of Step Transition Tests

@Suite("Size Transition Out Of Step With The Bounds", .serialized)
struct OutOfStepTransitionTests {

    @Test("An unfold that ends off screen, at the folded size, leaves the pages at the unfolded size once the column is back")
    @MainActor
    func unfoldEndingOffScreenResizesPagesWhenBack() {
        // Given: opened unfolded, then folded
        let (sut, host, window) = createController(columnSize: unfoldedColumnSize)
        defer { withExtendedLifetime(window) {} }
        resizeColumn(of: sut, in: host, window: window, to: foldedColumnSize)
        expectSnapped(sut, onPageAt: 2, columnWidth: foldedColumnSize.width)

        // When: the unfold reaches the pager while its column is off screen, and ends there
        host.removeColumnFromWindow()
        let coordinator = MockTransitionCoordinator()
        sut.viewWillTransition(to: unfoldedColumnSize, with: coordinator)
        coordinator.finishTransition()
        setColumnSize(unfoldedColumnSize, of: host, in: window)
        host.returnColumnToWindow()
        window.layoutIfNeeded()

        // Then
        expectSnapped(sut, onPageAt: 2, columnWidth: unfoldedColumnSize.width)
    }

    @Test("A transition that ends before its resize lands re-sizes the pages when the resize does")
    @MainActor
    func transitionEndingBeforeResizeResizesPagesWithIt() {
        // Given
        let (sut, host, window) = createController(columnSize: foldedColumnSize)
        defer { withExtendedLifetime(window) {} }

        // When: the transition ends at the old size, and the column resizes afterwards
        let coordinator = MockTransitionCoordinator()
        sut.viewWillTransition(to: unfoldedColumnSize, with: coordinator)
        coordinator.finishTransition()
        setColumnSize(unfoldedColumnSize, of: host, in: window)
        window.layoutIfNeeded()

        // Then
        expectSnapped(sut, onPageAt: 2, columnWidth: unfoldedColumnSize.width)
    }

    @Test("A transition that ends with its resize still pending lands on the current page at the new size",
          arguments: [(unfoldedColumnSize, widenedColumnSize), (widenedColumnSize, unfoldedColumnSize)])
    @MainActor
    func transitionEndingWithResizePendingLandsOnCurrentPage(from startSize: CGSize, to endSize: CGSize) {
        // Given
        let (sut, host, window) = createController(columnSize: startSize)
        defer { withExtendedLifetime(window) {} }

        // When: the column is resized, but the transition ends before a layout pass applies it
        let coordinator = MockTransitionCoordinator()
        sut.viewWillTransition(to: endSize, with: coordinator)
        setColumnSize(endSize, of: host, in: window)
        coordinator.finishTransition()

        // Then
        expectSnapped(sut, onPageAt: 2, columnWidth: endSize.width)

        // When: a later layout pass runs at the same size
        sut.view.setNeedsLayout()
        window.layoutIfNeeded()

        // Then: nothing moves
        expectSnapped(sut, onPageAt: 2, columnWidth: endSize.width)
    }

    @Test("A transition that arrives before the pages' first layout does not hold back their size")
    @MainActor
    func transitionBeforeFirstLayoutDoesNotHoldBackPageSize() {
        // Given: a loaded controller that has never been laid out is told about a transition
        let pages = (0..<5).map { _ in SwipePage(viewController: UIViewController()) }
        let sut = PageSwipeViewController(pages: pages)
        sut.loadViewIfNeeded()
        let coordinator = MockTransitionCoordinator()
        sut.viewWillTransition(to: unfoldedColumnSize, with: coordinator)

        // When: it is laid out for the first time while the transition runs
        let host = ColumnHostViewController(child: sut, columnWidth: unfoldedColumnSize.width)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1194, height: unfoldedColumnSize.height))
        defer { withExtendedLifetime(window) {} }
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        // Then: the pages already take the column's size
        expectSnapped(sut, onPageAt: 0, columnWidth: unfoldedColumnSize.width)

        // When: the transition ends
        coordinator.finishTransition()

        // Then
        expectSnapped(sut, onPageAt: 0, columnWidth: unfoldedColumnSize.width)
    }
}
