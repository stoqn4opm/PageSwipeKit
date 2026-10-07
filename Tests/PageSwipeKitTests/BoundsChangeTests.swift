//
//  BoundsChangeTests.swift
//  PageSwipeKitTests
//
//  The controller's view can change size without a size transition ever
//  reaching it: it sits in a split view column whose width is animated, a
//  sidebar tiles in or out beside it, or its container resizes. The pages
//  must still take the new size, stay on the current page and keep their
//  views, exactly as after a size transition.
//

import Testing
import UIKit
@testable import PageSwipeKit

// MARK: - Test Helpers

/// A container that hosts the controller in a column of adjustable width,
/// the way a split view hosts its column roots: the child's size changes
/// through plain constraint or frame changes and no size transition is
/// forwarded to it.
@MainActor
private final class ColumnHostViewController: UIViewController {

    let child: PageSwipeViewController
    private let initialColumnWidth: CGFloat
    private var columnConstraints: [NSLayoutConstraint] = []
    private var columnWidthConstraint: NSLayoutConstraint?

    init(child: PageSwipeViewController, columnWidth: CGFloat) {
        self.child = child
        self.initialColumnWidth = columnWidth
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(child)
        view.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false

        let columnWidthConstraint = child.view.widthAnchor.constraint(equalToConstant: initialColumnWidth)
        columnConstraints = [
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            columnWidthConstraint
        ]
        NSLayoutConstraint.activate(columnConstraints)
        self.columnWidthConstraint = columnWidthConstraint

        child.didMove(toParent: self)
    }

    /// Resizes the column through its width constraint.
    func setColumnWidth(_ width: CGFloat) {
        columnWidthConstraint?.constant = width
    }

    /// Hands the child's view over to frame-based layout, so the column can
    /// be resized by setting the frame directly.
    func switchColumnToFrameLayout() {
        NSLayoutConstraint.deactivate(columnConstraints)
        columnConstraints = []
        columnWidthConstraint = nil
        child.view.translatesAutoresizingMaskIntoConstraints = true
    }
}

private let windowFrame = CGRect(x: 0, y: 0, width: 1194, height: 834)
private let narrowColumnWidth: CGFloat = 554
private let wideColumnWidth: CGFloat = 834

/// Builds a controller with `pageCount` pages inside a column host, in a
/// window, already showing page `pageIndex`. The window is returned so the
/// test keeps it alive.
@MainActor
private func createColumnHostedController(
    pageCount: Int = 5,
    showingPageAt pageIndex: Int,
    columnWidth: CGFloat,
    configuration: PageSwipeConfiguration = .default
) -> (PageSwipeViewController, ColumnHostViewController, UIWindow) {
    let pages = (0..<pageCount).map { _ in SwipePage(viewController: UIViewController()) }
    let controller = PageSwipeViewController(pages: pages, configuration: configuration)
    let host = ColumnHostViewController(child: controller, columnWidth: columnWidth)

    let window = UIWindow(frame: windowFrame)
    window.rootViewController = host
    window.makeKeyAndVisible()
    window.layoutIfNeeded()

    controller.setCurrentPage(pages[pageIndex], animated: false)
    window.layoutIfNeeded()

    return (controller, host, window)
}

@MainActor
private func indexOfCurrentPage(in controller: PageSwipeViewController) -> Int? {
    controller.pages.firstIndex { $0.id == controller.currentPage?.id }
}

/// Asserts that the controller shows page `pageIndex` cleanly at the given
/// column width: every visible page has the collection view's size, the
/// offset sits exactly on the page's origin, no neighbour page peeks into
/// the viewport, and each visible page's view is hosted by its own cell.
@MainActor
private func expectSnapped(
    _ controller: PageSwipeViewController,
    onPageAt pageIndex: Int,
    columnWidth: CGFloat,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let scrollView = pagingCollectionView(of: controller)

    #expect(scrollView.bounds.width == columnWidth,
            "precondition: the collection view should be \(columnWidth) pt wide, got \(scrollView.bounds.width)",
            sourceLocation: sourceLocation)
    #expect(indexOfCurrentPage(in: controller) == pageIndex,
            "the current page should still be page \(pageIndex), got \(String(describing: indexOfCurrentPage(in: controller)))",
            sourceLocation: sourceLocation)
    #expect(scrollView.contentOffset.x == CGFloat(pageIndex) * columnWidth,
            "the offset should sit on page \(pageIndex)'s origin \(CGFloat(pageIndex) * columnWidth), got \(scrollView.contentOffset.x)",
            sourceLocation: sourceLocation)

    let currentPageCell = scrollView.cellForItem(at: IndexPath(item: pageIndex, section: 0))
    #expect(currentPageCell != nil, "the current page should have a visible cell", sourceLocation: sourceLocation)
    #expect(currentPageCell?.bounds.size == scrollView.bounds.size,
            "the current page should take the collection view's size \(scrollView.bounds.size), got \(String(describing: currentPageCell?.bounds.size))",
            sourceLocation: sourceLocation)

    for indexPath in scrollView.indexPathsForVisibleItems {
        guard let cell = scrollView.cellForItem(at: indexPath),
              let attributes = scrollView.layoutAttributesForItem(at: indexPath) else { continue }

        #expect(cell.bounds.width == columnWidth,
                "page \(indexPath.item) should be \(columnWidth) pt wide, got \(cell.bounds.width)",
                sourceLocation: sourceLocation)

        if indexPath.item != pageIndex {
            let overlap = attributes.frame.intersection(scrollView.bounds)
            #expect(overlap.isNull || overlap.width == 0,
                    "page \(indexPath.item) should not peek into the viewport, overlaps by \(overlap.width) pt",
                    sourceLocation: sourceLocation)
        }

        let pageView: UIView = controller.pages[indexPath.item].viewController.view
        #expect(pageView.superview === (cell as? PageCell)?.contentView,
                "page \(indexPath.item)'s view should be hosted by its own cell",
                sourceLocation: sourceLocation)
    }
}

// MARK: - Bounds Change Tests

@Suite("Bounds Change Re-snap", .serialized)
struct BoundsChangeTests {

    @Test("Widening the column re-sizes the pages and keeps the current page")
    @MainActor
    func wideningColumnResnapsCurrentPage() {
        // Given
        let (sut, host, window) = createColumnHostedController(showingPageAt: 2, columnWidth: narrowColumnWidth)
        defer { withExtendedLifetime(window) {} }
        expectSnapped(sut, onPageAt: 2, columnWidth: narrowColumnWidth)

        // When
        host.setColumnWidth(wideColumnWidth)
        window.layoutIfNeeded()

        // Then
        expectSnapped(sut, onPageAt: 2, columnWidth: wideColumnWidth)
    }

    @Test("Narrowing the column by setting its frame re-sizes the pages and keeps the current page")
    @MainActor
    func narrowingColumnFrameResnapsCurrentPage() {
        // Given
        let (sut, host, window) = createColumnHostedController(showingPageAt: 2, columnWidth: wideColumnWidth)
        defer { withExtendedLifetime(window) {} }
        host.switchColumnToFrameLayout()
        sut.view.frame = CGRect(x: windowFrame.width - wideColumnWidth, y: 0, width: wideColumnWidth, height: windowFrame.height)
        window.layoutIfNeeded()
        expectSnapped(sut, onPageAt: 2, columnWidth: wideColumnWidth)

        // When
        sut.view.frame = CGRect(x: windowFrame.width - narrowColumnWidth, y: 0, width: narrowColumnWidth, height: windowFrame.height)
        window.layoutIfNeeded()

        // Then
        expectSnapped(sut, onPageAt: 2, columnWidth: narrowColumnWidth)
    }

    @Test("Widening the column on the last page does not let the clamped offset pick another page")
    @MainActor
    func wideningColumnOnLastPageKeepsLastPage() {
        // Given
        let (sut, host, window) = createColumnHostedController(showingPageAt: 4, columnWidth: narrowColumnWidth)
        defer { withExtendedLifetime(window) {} }

        // When
        host.setColumnWidth(wideColumnWidth)
        window.layoutIfNeeded()

        // Then
        expectSnapped(sut, onPageAt: 4, columnWidth: wideColumnWidth)
    }

    @Test("An animated column resize lands on the current page at the new size")
    @MainActor
    func animatedColumnResizeResnapsCurrentPage() {
        // Given
        let (sut, host, window) = createColumnHostedController(showingPageAt: 1, columnWidth: narrowColumnWidth)
        defer { withExtendedLifetime(window) {} }

        // When
        UIView.animate(withDuration: 0.3) {
            host.setColumnWidth(wideColumnWidth)
            window.layoutIfNeeded()
        }

        // Then
        expectSnapped(sut, onPageAt: 1, columnWidth: wideColumnWidth)
    }

    @Test("A resize during a live scroll is left alone and re-snapped once the scroll ends")
    @MainActor
    func resizeDuringLiveScrollIsResnappedWhenScrollEnds() {
        // Given: the user is scrolling
        let (sut, host, window) = createColumnHostedController(showingPageAt: 2, columnWidth: narrowColumnWidth, configuration: .noScale)
        defer { withExtendedLifetime(window) {} }
        let scrollView = pagingCollectionView(of: sut)
        sut.scrollViewWillBeginDragging(scrollView)
        let offsetBeforeResize = scrollView.contentOffset

        // When: the column widens mid-scroll
        host.setColumnWidth(wideColumnWidth)
        window.layoutIfNeeded()

        // Then: the scroll is not fought
        #expect(scrollView.contentOffset == offsetBeforeResize, "the offset should be left to the live scroll, got \(scrollView.contentOffset)")

        // When: the scroll ends
        sut.scrollViewDidEndDecelerating(scrollView)

        // Then
        expectSnapped(sut, onPageAt: 2, columnWidth: wideColumnWidth)
    }

    @Test("When a size transition also arrives the page is re-snapped once, by the transition")
    @MainActor
    func sizeTransitionOwnsTheResnap() {
        // Given
        let (sut, host, window) = createColumnHostedController(showingPageAt: 2, columnWidth: narrowColumnWidth)
        defer { withExtendedLifetime(window) {} }
        let scrollView = pagingCollectionView(of: sut)
        let offsetBeforeTransition = scrollView.contentOffset

        // When: the column's root is told about the transition and its bounds change inside it
        let coordinator = MockTransitionCoordinator()
        sut.viewWillTransition(to: CGSize(width: wideColumnWidth, height: windowFrame.height), with: coordinator)
        host.setColumnWidth(wideColumnWidth)
        window.layoutIfNeeded()

        // Then: the layout pass leaves the re-snap to the transition
        #expect(scrollView.contentOffset == offsetBeforeTransition,
                "the layout pass should not re-snap while the transition owns it, got \(scrollView.contentOffset)")
        #expect(indexOfCurrentPage(in: sut) == 2, "the current page should not change mid-transition")

        // When: the transition settles
        coordinator.finishTransition()

        // Then
        expectSnapped(sut, onPageAt: 2, columnWidth: wideColumnWidth)

        // When: a later layout pass runs at the same size
        sut.view.setNeedsLayout()
        window.layoutIfNeeded()

        // Then: nothing moves
        expectSnapped(sut, onPageAt: 2, columnWidth: wideColumnWidth)
    }

    @Test("A re-snap does not announce a page change")
    @MainActor
    func resnapDoesNotAnnounceAPageChange() async throws {
        // Given
        let (sut, host, window) = createColumnHostedController(showingPageAt: 2, columnWidth: narrowColumnWidth)
        defer { withExtendedLifetime(window) {} }
        var announcedPageIDs: [UUID] = []
        let subscription = sut.currentPageDidChangePublisher.sink { announcedPageIDs.append($0.id) }
        defer { subscription.cancel() }
        try await wait(milliseconds: 50)
        let announcedBeforeResize = announcedPageIDs

        // When
        host.setColumnWidth(wideColumnWidth)
        window.layoutIfNeeded()
        host.setColumnWidth(narrowColumnWidth)
        window.layoutIfNeeded()
        try await wait(milliseconds: 50)

        // Then
        #expect(announcedBeforeResize == [sut.pages[2].id], "precondition: the subscription should get the current page once")
        #expect(announcedPageIDs == announcedBeforeResize, "resizing should not announce any page, got \(announcedPageIDs.count - announcedBeforeResize.count) extra")
    }
}
