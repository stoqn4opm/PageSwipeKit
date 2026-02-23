//
//  PrefetchingTests.swift
//  PageSwipeKitTests
//
//  Tests for the prefetching logic in PageSwipeViewController.
//

import Testing
import UIKit
@testable import PageSwipeKit

// MARK: - Mock Prefetchable

final class MockPrefetchable: Prefetchable, @unchecked Sendable {
    private(set) var prefetchCallCount = 0
    let name: String

    init(name: String) {
        self.name = name
    }

    func prefetchData() {
        prefetchCallCount += 1
    }

    func reset() {
        prefetchCallCount = 0
    }
}

// MARK: - Test Helpers

@MainActor
func createMockPage(name: String) -> (SwipePage, MockPrefetchable) {
    let prefetchable = MockPrefetchable(name: name)
    let viewController = UIViewController()
    let page = SwipePage(viewController: viewController, prefetchable: prefetchable)
    return (page, prefetchable)
}

@MainActor
func createPageSwipeVC(pageCount: Int) -> (PageSwipeViewController, [MockPrefetchable]) {
    var prefetchables: [MockPrefetchable] = []
    var pages: [SwipePage] = []

    for i in 0..<pageCount {
        let (page, prefetchable) = createMockPage(name: "Page\(i)")
        pages.append(page)
        prefetchables.append(prefetchable)
    }

    let vc = PageSwipeViewController(pages: pages)
    return (vc, prefetchables)
}

@MainActor
func loadViewController(_ vc: UIViewController) {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
    window.rootViewController = vc
    window.makeKeyAndVisible()
    vc.loadViewIfNeeded()
    vc.view.layoutIfNeeded()
}

@MainActor
func waitForAsyncOperations() async {
    try? await Task.sleep(nanoseconds: 100_000_000)
}

// MARK: - Prepend Tests

@Suite("Prepend Prefetching")
struct PrependPrefetchingTests {

    @Test("Prepending a page triggers exactly one prefetch call")
    @MainActor
    func prependTriggersOnePrefetch() async {
        // Given
        let (sut, _) = createPageSwipeVC(pageCount: 3)
        loadViewController(sut)
        let (newPage, newPrefetchable) = createMockPage(name: "Prepended")

        // When
        sut.prepend(newPage)
        await waitForAsyncOperations()

        // Then
        #expect(newPrefetchable.prefetchCallCount == 1, "Prepended page should be prefetched exactly once, got \(newPrefetchable.prefetchCallCount)")
    }

    @Test("Prepending does not trigger prefetch on existing neighbor pages")
    @MainActor
    func prependDoesNotPrefetchExistingNeighbors() async {
        // Given
        let (sut, existingPrefetchables) = createPageSwipeVC(pageCount: 3)
        loadViewController(sut)
        for p in existingPrefetchables { p.reset() }
        await waitForAsyncOperations()
        for p in existingPrefetchables { p.reset() }
        let (newPage, _) = createMockPage(name: "Prepended")

        // When
        sut.prepend(newPage)
        await waitForAsyncOperations()

        // Then
        for (index, prefetchable) in existingPrefetchables.enumerated() {
            #expect(prefetchable.prefetchCallCount == 0, "Existing page at index \(index) should not be prefetched on prepend, got \(prefetchable.prefetchCallCount)")
        }
    }

    @Test("Multiple prepends each trigger exactly one prefetch")
    @MainActor
    func multiplePrepends() async {
        // Given
        let (sut, _) = createPageSwipeVC(pageCount: 2)
        loadViewController(sut)
        let (page1, prefetchable1) = createMockPage(name: "Prepended1")
        let (page2, prefetchable2) = createMockPage(name: "Prepended2")

        // When
        sut.prepend(page1)
        await waitForAsyncOperations()
        sut.prepend(page2)
        await waitForAsyncOperations()

        // Then
        #expect(prefetchable1.prefetchCallCount == 1, "First prepended page should be prefetched exactly once")
        #expect(prefetchable2.prefetchCallCount == 1, "Second prepended page should be prefetched exactly once")
    }
}

// MARK: - Append Tests

@Suite("Append Prefetching")
struct AppendPrefetchingTests {

    @Test("Appending a page triggers exactly one prefetch call")
    @MainActor
    func appendTriggersOnePrefetch() async {
        // Given
        let (sut, _) = createPageSwipeVC(pageCount: 3)
        loadViewController(sut)
        let (newPage, newPrefetchable) = createMockPage(name: "Appended")

        // When
        sut.append(newPage)
        await waitForAsyncOperations()

        // Then
        #expect(newPrefetchable.prefetchCallCount == 1, "Appended page should be prefetched exactly once, got \(newPrefetchable.prefetchCallCount)")
    }

    @Test("Multiple appends each trigger exactly one prefetch")
    @MainActor
    func multipleAppends() async {
        // Given
        let (sut, _) = createPageSwipeVC(pageCount: 2)
        loadViewController(sut)
        let (page1, prefetchable1) = createMockPage(name: "Appended1")
        let (page2, prefetchable2) = createMockPage(name: "Appended2")

        // When
        sut.append(page1)
        await waitForAsyncOperations()
        sut.append(page2)
        await waitForAsyncOperations()

        // Then
        #expect(prefetchable1.prefetchCallCount == 1, "First appended page should be prefetched exactly once")
        #expect(prefetchable2.prefetchCallCount == 1, "Second appended page should be prefetched exactly once")
    }
}

// MARK: - Page Navigation Tests

@Suite("Navigation Prefetching")
struct NavigationPrefetchingTests {

    @Test("Going to next page prefetches neighbors")
    @MainActor
    func goToNextPagePrefetchesNeighbors() async {
        // Given
        let (sut, prefetchables) = createPageSwipeVC(pageCount: 5)
        loadViewController(sut)
        for p in prefetchables { p.reset() }
        await waitForAsyncOperations()
        for p in prefetchables { p.reset() }

        // When
        sut.goToNextPage(animated: false)
        await waitForAsyncOperations()

        // Then
        #expect(prefetchables[2].prefetchCallCount >= 1, "Page at index 2 (next neighbor) should be prefetched")
    }

    @Test("Going to previous page prefetches neighbors")
    @MainActor
    func goToPreviousPagePrefetchesNeighbors() async {
        // Given
        let (sut, prefetchables) = createPageSwipeVC(pageCount: 5)
        loadViewController(sut)
        sut.goToNextPage(animated: false)
        try? await Task.sleep(nanoseconds: 50_000_000)
        sut.goToNextPage(animated: false)
        await waitForAsyncOperations()
        for p in prefetchables { p.reset() }

        // When
        sut.goToPreviousPage(animated: false)
        await waitForAsyncOperations()

        // Then
        #expect(prefetchables[0].prefetchCallCount >= 1, "Page at index 0 (previous neighbor) should be prefetched")
    }
}

// MARK: - Edge Cases

@Suite("Edge Cases")
struct EdgeCaseTests {

    @Test("Prepending when on first page only prefetches the new page")
    @MainActor
    func prependWhenOnFirstPage() async {
        // Given
        let (sut, existingPrefetchables) = createPageSwipeVC(pageCount: 3)
        loadViewController(sut)
        for p in existingPrefetchables { p.reset() }
        await waitForAsyncOperations()
        for p in existingPrefetchables { p.reset() }
        let (newPage, newPrefetchable) = createMockPage(name: "Prepended")

        // When
        sut.prepend(newPage)
        await waitForAsyncOperations()

        // Then
        #expect(newPrefetchable.prefetchCallCount == 1, "Prepended page should be prefetched exactly once")
        for (index, p) in existingPrefetchables.enumerated() {
            #expect(p.prefetchCallCount == 0, "Existing page at index \(index) should not be prefetched")
        }
    }

    @Test("Page count increases by one after prepend")
    @MainActor
    func pageCountAfterPrepend() {
        // Given
        let (sut, _) = createPageSwipeVC(pageCount: 3)
        loadViewController(sut)
        let initialCount = sut.pages.count
        let (newPage, _) = createMockPage(name: "Prepended")

        // When
        sut.prepend(newPage)

        // Then
        #expect(sut.pages.count == initialCount + 1, "Page count should increase by 1 after prepend")
    }

    @Test("Page count increases by one after append")
    @MainActor
    func pageCountAfterAppend() {
        // Given
        let (sut, _) = createPageSwipeVC(pageCount: 3)
        loadViewController(sut)
        let initialCount = sut.pages.count
        let (newPage, _) = createMockPage(name: "Appended")

        // When
        sut.append(newPage)

        // Then
        #expect(sut.pages.count == initialCount + 1, "Page count should increase by 1 after append")
    }

    @Test("Current page remains unchanged after prepend")
    @MainActor
    func currentPageUnchangedAfterPrepend() async {
        // Given
        let (sut, _) = createPageSwipeVC(pageCount: 3)
        loadViewController(sut)
        let currentPageBefore = sut.currentPage
        let (newPage, _) = createMockPage(name: "Prepended")

        // When
        sut.prepend(newPage)
        await waitForAsyncOperations()

        // Then
        let currentPageAfter = sut.currentPage
        #expect(currentPageBefore?.id == currentPageAfter?.id, "Current page should remain the same after prepend")
    }
}
