//
//  SizeTransitionTests.swift
//  PageSwipeKitTests
//
//  Tests for size-transition (rotation) recovery in PageSwipeViewController
//  and for PageCell's idempotent view hosting.
//

import Testing
import UIKit
@testable import PageSwipeKit

// MARK: - Mock Transition Coordinator

/// Stands in for the system's transition coordinator: records the alongside
/// animations and completions handed to it, and replays them on demand so a
/// test controls exactly when "the rotation finished".
@MainActor
final class MockTransitionCoordinator: NSObject, UIViewControllerTransitionCoordinator {

    private var alongsideAnimations: [(any UIViewControllerTransitionCoordinatorContext) -> Void] = []
    private var completions: [(any UIViewControllerTransitionCoordinatorContext) -> Void] = []

    /// Runs the recorded alongside animations, then the recorded completions —
    /// the order the real coordinator uses once the transition settles.
    func finishTransition() {
        for animation in alongsideAnimations { animation(self) }
        for completion in completions { completion(self) }
    }

    // MARK: UIViewControllerTransitionCoordinator

    func animate(alongsideTransition animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
                 completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?) -> Bool {
        if let animation { alongsideAnimations.append(animation) }
        if let completion { completions.append(completion) }
        return true
    }

    func animateAlongsideTransition(in view: UIView?,
                                    animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
                                    completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?) -> Bool {
        if let animation { alongsideAnimations.append(animation) }
        if let completion { completions.append(completion) }
        return true
    }

    func notifyWhenInteractionChanges(_ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void) {}
    func notifyWhenInteractionEnds(_ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void) {}

    // MARK: UIViewControllerTransitionCoordinatorContext

    var isAnimated: Bool { false }
    var presentationStyle: UIModalPresentationStyle { .none }
    var initiallyInteractive: Bool { false }
    var isInterruptible: Bool { false }
    var isInteractive: Bool { false }
    var isCancelled: Bool { false }
    var transitionDuration: TimeInterval { 0 }
    var percentComplete: CGFloat { 1 }
    var completionVelocity: CGFloat { 1 }
    var completionCurve: UIView.AnimationCurve { .linear }
    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { nil }
    func view(forKey key: UITransitionContextViewKey) -> UIView? { nil }
    var containerView: UIView { UIView() }
    var targetTransform: CGAffineTransform { .identity }
}

// MARK: - Test Helpers

private let portraitFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
private let landscapeFrame = CGRect(x: 0, y: 0, width: 812, height: 375)

/// Builds a loaded PageSwipeViewController inside a portrait window and
/// returns the window alongside so tests can resize it to simulate rotation.
@MainActor
private func createLoadedController(pageCount: Int) -> (PageSwipeViewController, UIWindow) {
    let pages = (0..<pageCount).map { _ in SwipePage(viewController: UIViewController()) }
    let controller = PageSwipeViewController(pages: pages)

    let window = UIWindow(frame: portraitFrame)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.loadViewIfNeeded()
    controller.view.layoutIfNeeded()

    return (controller, window)
}

@MainActor
private func collectionView(of controller: PageSwipeViewController) -> UICollectionView? {
    controller.view.subviews.compactMap { $0 as? UICollectionView }.first
}

/// Drives the controller through a simulated rotation: announces the
/// transition, resizes the window, then finishes the coordinator.
@MainActor
private func rotate(_ controller: PageSwipeViewController, in window: UIWindow, to frame: CGRect) {
    let coordinator = MockTransitionCoordinator()
    controller.viewWillTransition(to: frame.size, with: coordinator)

    window.frame = frame
    window.layoutIfNeeded()

    coordinator.finishTransition()
}

// MARK: - Rotation Page Preservation Tests

@Suite("Rotation Page Preservation")
struct RotationPagePreservationTests {

    @Test("Current page survives a rotation to landscape")
    @MainActor
    func currentPageSurvivesRotation() {
        // Given
        let (sut, window) = createLoadedController(pageCount: 3)
        sut.setCurrentPage(sut.pages[2], animated: false)
        let pageBefore = sut.currentPage

        // When
        rotate(sut, in: window, to: landscapeFrame)

        // Then
        #expect(sut.currentPage?.id == pageBefore?.id, "Current page should be the same page after rotation")
    }

    @Test("Current page survives a full rotation round trip")
    @MainActor
    func currentPageSurvivesRotationRoundTrip() {
        // Given
        let (sut, window) = createLoadedController(pageCount: 4)
        sut.setCurrentPage(sut.pages[3], animated: false)
        let pageBefore = sut.currentPage

        // When
        rotate(sut, in: window, to: landscapeFrame)
        rotate(sut, in: window, to: portraitFrame)

        // Then
        #expect(sut.currentPage?.id == pageBefore?.id, "Current page should survive landscape and back")
    }

    @Test("Content offset snaps to the current page's new origin after rotation")
    @MainActor
    func contentOffsetSnapsToPageOriginAfterRotation() {
        // Given
        let (sut, window) = createLoadedController(pageCount: 3)
        sut.setCurrentPage(sut.pages[2], animated: false)

        // When
        rotate(sut, in: window, to: landscapeFrame)

        // Then
        let offset = collectionView(of: sut)?.contentOffset.x
        let expectedOffset = landscapeFrame.width * 2
        #expect(offset == expectedOffset, "Offset should be exactly two page widths in landscape, got \(String(describing: offset))")
    }

    @Test("Interim content offsets during the transition do not corrupt the current page")
    @MainActor
    func interimOffsetsDoNotCorruptCurrentPage() {
        // Given
        let (sut, window) = createLoadedController(pageCount: 3)
        sut.setCurrentPage(sut.pages[2], animated: false)
        let pageBefore = sut.currentPage

        let coordinator = MockTransitionCoordinator()
        sut.viewWillTransition(to: landscapeFrame.size, with: coordinator)
        window.frame = landscapeFrame
        window.layoutIfNeeded()

        // When: mid-animation the scroll view reports an offset belonging to another page
        collectionView(of: sut)?.contentOffset = CGPoint(x: 0, y: 0)

        // Then: still suppressed before the transition completes
        #expect(sut.currentPage?.id == pageBefore?.id, "Interim offsets must not re-derive the current page mid-transition")

        // When the transition settles
        coordinator.finishTransition()

        // Then
        #expect(sut.currentPage?.id == pageBefore?.id, "Current page should be restored once the transition completes")
    }

    @Test("Rotation before the view loads is harmless")
    @MainActor
    func rotationBeforeViewLoadsIsHarmless() {
        // Given
        let pages = (0..<2).map { _ in SwipePage(viewController: UIViewController()) }
        let sut = PageSwipeViewController(pages: pages)
        let coordinator = MockTransitionCoordinator()

        // When
        sut.viewWillTransition(to: landscapeFrame.size, with: coordinator)
        coordinator.finishTransition()

        // Then
        #expect(sut.currentPage?.id == pages[0].id, "Unloaded controller should keep its initial page")
    }
}

// MARK: - Rotation View Reattachment Tests

@Suite("Rotation View Reattachment")
struct RotationViewReattachmentTests {

    @Test("Current page's view is hosted in a visible cell after rotation")
    @MainActor
    func currentPageViewHostedAfterRotation() {
        // Given
        let (sut, window) = createLoadedController(pageCount: 3)
        sut.setCurrentPage(sut.pages[1], animated: false)
        collectionView(of: sut)?.layoutIfNeeded()

        // When
        rotate(sut, in: window, to: landscapeFrame)

        // Then
        let pageView: UIView = sut.pages[1].viewController.view
        #expect(pageView.window === window, "Current page's view should be back in the window after rotation")
        let hostingCell = collectionView(of: sut)?.visibleCells.first { pageView.isDescendant(of: $0) }
        #expect(hostingCell != nil, "Current page's view should live inside a visible cell")
    }

    @Test("A page view stolen by a transient cell is re-attached after rotation")
    @MainActor
    func stolenPageViewIsReattachedAfterRotation() {
        // Given
        let (sut, window) = createLoadedController(pageCount: 3)
        sut.setCurrentPage(sut.pages[1], animated: false)
        collectionView(of: sut)?.layoutIfNeeded()

        let coordinator = MockTransitionCoordinator()
        sut.viewWillTransition(to: landscapeFrame.size, with: coordinator)
        window.frame = landscapeFrame
        window.layoutIfNeeded()

        // When: a transient animation cell steals the page's view mid-transition
        let transientCell = PageCell(frame: landscapeFrame)
        transientCell.configure(with: sut.pages[1].viewController.view)
        coordinator.finishTransition()

        // Then
        let pageView: UIView = sut.pages[1].viewController.view
        #expect(pageView.isDescendant(of: sut.view), "Stolen page view should be re-attached to a surviving cell")
        #expect(!pageView.isDescendant(of: transientCell), "Stolen page view should no longer live in the transient cell")
    }
}

// MARK: - Page Cell Hosting Tests

@Suite("Page Cell Hosting")
struct PageCellHostingTests {

    @Test("Re-configuring with the same view does not accumulate constraints")
    @MainActor
    func reconfigureDoesNotAccumulateConstraints() {
        // Given
        let cell = PageCell(frame: portraitFrame)
        let view = UIView()
        cell.configure(with: view)
        let constraintCountAfterFirstConfigure = cell.contentView.constraints.count

        // When
        cell.configure(with: view)
        cell.configure(with: view)

        // Then
        #expect(cell.contentView.constraints.count == constraintCountAfterFirstConfigure, "Repeated configuration with the same view must not add constraints")
        #expect(view.superview === cell.contentView, "View should remain hosted by the cell")
    }

    @Test("Configuring with a new view replaces the previous one")
    @MainActor
    func configureReplacesPreviousView() {
        // Given
        let cell = PageCell(frame: portraitFrame)
        let firstView = UIView()
        let secondView = UIView()
        cell.configure(with: firstView)

        // When
        cell.configure(with: secondView)

        // Then
        #expect(firstView.superview == nil, "Previous view should be removed")
        #expect(secondView.superview === cell.contentView, "New view should be hosted")
    }

    @Test("Configure wins the view back from another cell")
    @MainActor
    func configureReclaimsViewFromAnotherCell() {
        // Given
        let view = UIView()
        let firstCell = PageCell(frame: portraitFrame)
        let secondCell = PageCell(frame: portraitFrame)
        firstCell.configure(with: view)

        // When
        secondCell.configure(with: view)

        // Then
        #expect(view.superview === secondCell.contentView, "View should move to the configuring cell")
    }

    @Test("Recycling a cell that lost its view does not rip it from the new owner")
    @MainActor
    func recyclingLoserCellDoesNotStealViewBack() {
        // Given
        let view = UIView()
        let loserCell = PageCell(frame: portraitFrame)
        let ownerCell = PageCell(frame: portraitFrame)
        loserCell.configure(with: view)
        ownerCell.configure(with: view)

        // When
        loserCell.prepareForReuse()

        // Then
        #expect(view.superview === ownerCell.contentView, "Recycling the loser cell must not remove the view from its current owner")
    }

    @Test("Recycling the owning cell removes its hosted view")
    @MainActor
    func recyclingOwnerCellRemovesHostedView() {
        // Given
        let cell = PageCell(frame: portraitFrame)
        let view = UIView()
        cell.configure(with: view)

        // When
        cell.prepareForReuse()

        // Then
        #expect(view.superview == nil, "Recycling the owning cell should unhost its view")
    }
}
