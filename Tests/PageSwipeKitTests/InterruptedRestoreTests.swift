//
//  InterruptedRestoreTests.swift
//  PageSwipeKitTests
//
//  A drag that begins while the settle animation is still running takes over
//  from what is on screen: the in-flight scale/corner animation is dropped and
//  the cells keep the values they were drawn with. A touch-to-stop during
//  deceleration, by contrast, must leave the running scale-down alone.
//

import Testing
import Combine
import UIKit
@testable import PageSwipeKit

@Suite("Interrupted Restore", .serialized)
struct InterruptedRestoreTests {

    @Test("Uniform scaling: a drag that begins during the restore cancels it and keeps the on-screen scale")
    @MainActor
    func dragDuringRestoreKeepsOnScreenScaleUniform() async throws {
        // Given: the restore spring is in flight
        let (sut, window) = createLoadedController(configuration: settleConfiguration)
        defer { withExtendedLifetime(window) {} }
        let scrollView = pagingCollectionView(of: sut)
        sut.scrollViewWillBeginDragging(scrollView)
        try await wait(milliseconds: 300)
        sut.scrollViewDidEndDecelerating(scrollView)
        try await wait(milliseconds: 100)
        #expect(hasScaleAnimation(in: scrollView), "precondition: the restore animation should be in flight")

        // When
        sut.scrollViewWillBeginDragging(scrollView)

        // Then
        let cell = try #require(scrollView.visibleCells.first)
        #expect(!hasScaleAnimation(in: scrollView), "the in-flight restore animation should be dropped")
        #expect(cell.transform.a >= 0.92 && cell.transform.a < 1.0,
                "the model scale should be frozen at the on-screen value, got \(cell.transform.a)")
    }

    @Test("Progressive scaling: a drag that begins during the restore cancels it and keeps the on-screen corner radius")
    @MainActor
    func dragDuringRestoreKeepsOnScreenCornerRadiusProgressive() async throws {
        // Given: the centred cell carries its concentric radius and the restore spring is in flight
        let (sut, window) = createLoadedController(configuration: progressiveSettleConfiguration)
        defer { withExtendedLifetime(window) {} }
        let scrollView = pagingCollectionView(of: sut)
        sut.scrollViewWillBeginDragging(scrollView)
        sut.scrollViewDidScroll(scrollView)
        try await wait(milliseconds: 50)
        sut.scrollViewDidEndDecelerating(scrollView)
        try await wait(milliseconds: 100)
        #expect(hasScaleAnimation(in: scrollView), "precondition: the restore animation should be in flight")

        // When
        sut.scrollViewWillBeginDragging(scrollView)

        // Then
        let cell = try #require(scrollView.visibleCells.first)
        #expect(!hasScaleAnimation(in: scrollView), "the in-flight restore animation should be dropped")
        #expect(cell.transform == .identity)
        #expect(cell.layer.cornerRadius > 0 && cell.layer.cornerRadius <= 55,
                "the corner radius should be frozen at the on-screen value, got \(cell.layer.cornerRadius)")
    }

    @Test("A touch-to-stop during deceleration leaves the scale-down running and begins scrolling only once")
    @MainActor
    func touchToStopDuringDecelerationLeavesScaleDownRunning() async throws {
        // Given: the scale-down is in flight and scrolling has begun once
        let (sut, window) = createLoadedController(configuration: PageSwipeConfiguration(scaleDownDuration: 2))
        defer { withExtendedLifetime(window) {} }
        let scrollView = pagingCollectionView(of: sut)
        var scrollingDidBeginCount = 0
        let subscription = sut.scrollingDidBeginPublisher.sink { scrollingDidBeginCount += 1 }
        defer { subscription.cancel() }
        sut.scrollViewWillBeginDragging(scrollView)
        try await wait(milliseconds: 100)
        #expect(hasScaleAnimation(in: scrollView), "precondition: the scale-down animation should be in flight")

        // When
        sut.scrollViewWillBeginDragging(scrollView)
        try await wait(milliseconds: 50)

        // Then
        #expect(hasScaleAnimation(in: scrollView), "the running scale-down should be left alone")
        #expect(sut.isScrolling)
        #expect(scrollingDidBeginCount == 1)
    }
}
