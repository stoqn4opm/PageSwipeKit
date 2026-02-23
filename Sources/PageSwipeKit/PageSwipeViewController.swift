//
//  PageSwipeViewController.swift
//  ScrollViewTest
//
//  Created by stoyan on 23.02.26.
//

import UIKit
import SwiftUI
import Combine

// MARK: - PageSwipeViewController

public final class PageSwipeViewController: UIViewController {
    
    // MARK: - Public Properties
    
    /// Configuration for page swipe behavior.
    @Published public var configuration: PageSwipeConfiguration
    
    /// All pages in the controller.
    public private(set) var pages: [SwipePage]
    
    /// The current page. Returns `nil` if there are no pages.
    public var currentPage: SwipePage? {
        guard pages.indices.contains(currentPageIndex) else { return nil }
        return pages[currentPageIndex]
    }
    
    /// Whether there are pages after the current page.
    public var hasNextPage: Bool { currentPageIndex < pages.count - 1 }
    
    /// Whether there are pages before the current page.
    public var hasPreviousPage: Bool { currentPageIndex > 0 }
    
    /// Whether the controller is currently scrolling.
    @Published public private(set) var isScrolling = false
    
    // MARK: - Private Properties
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!
    @Published private var currentPageIndex: Int = 0
    private var isAdjustingContentOffset = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Private Subjects
    
    private let scrollingDidBeginSubject = PassthroughSubject<Void, Never>()
    private let scrollingDidEndSubject = PassthroughSubject<Void, Never>()
    private let contentOffsetSubject = PassthroughSubject<CGPoint, Never>()
    
    // MARK: - Initialization
    
    /// Creates a container with the given pages and configuration.
    /// - Parameters:
    ///   - pages: Array of SwipePage objects to display.
    ///   - configuration: Configuration for swipe behavior. Defaults to `.default`.
    public init(pages: [SwipePage], configuration: PageSwipeConfiguration = .default) {
        self.pages = pages
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    
    /// Creates a container with view controllers (without prefetchables).
    /// - Parameters:
    ///   - viewControllers: Array of view controllers to display as pages.
    ///   - configuration: Configuration for swipe behavior. Defaults to `.default`.
    public init(viewControllers: [UIViewController], configuration: PageSwipeConfiguration = .default) {
        self.pages = viewControllers.map { SwipePage(viewController: $0) }
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported. Use init(pages:configuration:) instead.")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupCollectionView()
        setupDataSource()
        setupBindings()
        addAllChildViewControllers()
        applySnapshot(animatingDifferences: false)
    }
    
    public override var childForStatusBarStyle: UIViewController? {
        currentPageViewController
    }
    
    public override var childForStatusBarHidden: UIViewController? {
        currentPageViewController
    }
    
    public override var childForHomeIndicatorAutoHidden: UIViewController? {
        currentPageViewController
    }
}

// MARK: - Publishers

extension PageSwipeViewController {
    
    /// Publisher that emits when scrolling begins.
    public var scrollingDidBeginPublisher: AnyPublisher<Void, Never> {
        scrollingDidBeginSubject
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when scrolling ends.
    public var scrollingDidEndPublisher: AnyPublisher<Void, Never> {
        scrollingDidEndSubject
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits the current SwipePage immediately upon subscription and after every page change.
    public var currentPageDidChangePublisher: AnyPublisher<SwipePage, Never> {
        Just(pages[currentPageIndex])
            .merge(with: $currentPageIndex
                .dropFirst()
                .compactMap { [weak self] index in self?.pages[index] }
            )
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Public Methods

extension PageSwipeViewController {
    
    /// Navigates to the specified page.
    /// - Parameters:
    ///   - page: The target page.
    ///   - animated: Whether to animate the transition.
    public func setCurrentPage(_ page: SwipePage, animated: Bool) {
        guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return }
        
        let targetOffset = CGPoint(x: CGFloat(index) * collectionView.bounds.width, y: 0)
        collectionView.setContentOffset(targetOffset, animated: animated)
        currentPageIndex = index
    }
    
    /// Advances to the next page if available.
    /// - Parameter animated: Whether to animate the transition.
    public func goToNextPage(animated: Bool = true) {
        guard let nextPage = pageAt(index: currentPageIndex + 1) else { return }
        setCurrentPage(nextPage, animated: animated)
    }
    
    /// Returns to the previous page if available.
    /// - Parameter animated: Whether to animate the transition.
    public func goToPreviousPage(animated: Bool = true) {
        guard let previousPage = pageAt(index: currentPageIndex - 1) else { return }
        setCurrentPage(previousPage, animated: animated)
    }
    
    /// Returns the page at the specified index, or nil if out of bounds.
    private func pageAt(index: Int) -> SwipePage? {
        guard index >= 0, index < pages.count else { return nil }
        return pages[index]
    }
    
    /// Replaces all pages with new pages.
    /// - Parameters:
    ///   - newPages: The new pages to display.
    ///   - initialPage: The initial page to display. Defaults to the first page.
    public func setPages(_ newPages: [SwipePage], initialPage: SwipePage? = nil) {
        removeAllChildViewControllers()
        
        pages = newPages
        addAllChildViewControllers()
        applySnapshot(animatingDifferences: false)
        
        if let initialPage, let index = pages.firstIndex(where: { $0.id == initialPage.id }) {
            currentPageIndex = index
        } else {
            currentPageIndex = 0
        }
        
        if let page = pageAt(index: currentPageIndex) {
            setCurrentPage(page, animated: false)
        }
    }
    
    /// Appends a page to the end of the pages.
    /// - Parameter page: The SwipePage to append.
    public func append(_ page: SwipePage) {
        embedChildViewController(page.viewController)
        pages.append(page)
        applySnapshot()
        
        page.prefetchable?.prefetchData()
    }
    
    /// Prepends a page to the beginning of the pages.
    /// Automatically adjusts the current page index to maintain the same visible page.
    /// - Parameter page: The SwipePage to prepend.
    public func prepend(_ page: SwipePage) {
        embedChildViewController(page.viewController)
        pages.insert(page, at: 0)
        
        let pageWidth = collectionView.bounds.width
        
        isAdjustingContentOffset = true
        
        applySnapshot(animatingDifferences: false)
        
        let newOffset = CGPoint(x: collectionView.contentOffset.x + pageWidth, y: 0)
        collectionView.setContentOffset(newOffset, animated: false)
        currentPageIndex += 1
        
        // Reset flag after the current run loop to ensure the async
        // currentPageIndex publisher doesn't trigger notifyNeighborPages
        DispatchQueue.main.async { [weak self] in
            self?.isAdjustingContentOffset = false
        }
        
        page.prefetchable?.prefetchData()
    }
    
    /// Removes the specified page.
    /// - Parameter page: The SwipePage to remove.
    public func remove(_ page: SwipePage) {
        guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return }
        
        unembed(page.viewController)
        pages.remove(at: index)
        
        applySnapshot()
        
        if currentPageIndex >= pages.count {
            currentPageIndex = max(0, pages.count - 1)
        } else if index < currentPageIndex {
            currentPageIndex -= 1
        }
    }
}

// MARK: - Private Setup

extension PageSwipeViewController {
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.register(PageCell.self, forCellWithReuseIdentifier: PageCell.identifier)
        collectionView.clipsToBounds = false
        collectionView.contentInsetAdjustmentBehavior = .never
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, UUID>(collectionView: collectionView) { [weak self] collectionView, indexPath, identifier in
            guard let self else { return nil }
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PageCell.identifier, for: indexPath) as? PageCell else { return nil }
            guard let page = pages.first(where: { $0.id == identifier }) else { return cell }
            
            cell.configure(with: page.viewController.view)
            
            guard isScrolling else { return cell }
            
            let scale = configuration.transitionScale
            cell.transform = CGAffineTransform(scaleX: scale, y: scale)
            cell.layer.cornerRadius = concentricCornerRadius(for: scale)
            cell.layer.masksToBounds = true
            
            return cell
        }
    }
    
    private func setupBindings() {
        setupConfigurationBinding()
        setupScrollingStateBinding()
        setupPageIndexBinding()
        setupContentOffsetBinding()
    }
    
    private func setupConfigurationBinding() {
        $configuration
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleConfigurationChange()
            }
            .store(in: &cancellables)
    }
    
    private func setupScrollingStateBinding() {
        $isScrolling
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scrolling in
                guard let self else { return }
                
                if scrolling {
                    applyScaleToVisibleCells(animated: true)
                } else {
                    restoreScaleToVisibleCells(animated: true)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPageIndexBinding() {
        $currentPageIndex
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !isAdjustingContentOffset else { return }
                notifyNeighborPages()
            }
            .store(in: &cancellables)
    }
    
    private func setupContentOffsetBinding() {
        contentOffsetSubject
            .filter { [weak self] _ in
                self?.configuration.scalingBehavior == .progressive
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateProgressiveScaling()
            }
            .store(in: &cancellables)
    }
    
    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(pages.map { $0.id })
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
}

// MARK: - Child View Controller Management

extension PageSwipeViewController {
    
    private var currentPageViewController: UIViewController? {
        guard pages.indices.contains(currentPageIndex) else { return nil }
        return pages[currentPageIndex].viewController
    }
    
    private func addAllChildViewControllers() {
        for page in pages {
            embedChildViewController(page.viewController)
        }
    }
    
    private func embedChildViewController(_ viewController: UIViewController) {
        addChild(viewController)
        viewController.didMove(toParent: self)
    }
    
    private func unembed(_ viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
    
    private func removeAllChildViewControllers() {
        for page in pages {
            unembed(page.viewController)
        }
    }
}

// MARK: - Configuration Handling

extension PageSwipeViewController {
    
    private func handleConfigurationChange() {
        guard collectionView != nil else { return }
        
        if !isScrolling {
            resetVisibleCellsToIdentity()
        } else if configuration.scalingBehavior == .progressive {
            updateProgressiveScaling()
        } else if configuration.scalingBehavior == .none {
            resetVisibleCellsToIdentity()
        }
    }
    
    private func resetVisibleCellsToIdentity() {
        for cell in collectionView.visibleCells {
            cell.transform = .identity
            cell.layer.cornerRadius = 0
        }
    }
}

// MARK: - Scaling

extension PageSwipeViewController {
    
    private func applyScaleToVisibleCells(animated: Bool) {
        guard configuration.scalingBehavior == .uniform else { return }
        
        let scale = configuration.transitionScale
        let cornerRadius = concentricCornerRadius(for: scale)
        
        let applyTransform = {
            for cell in self.collectionView.visibleCells {
                cell.transform = CGAffineTransform(scaleX: scale, y: scale)
                cell.layer.cornerRadius = cornerRadius
                cell.layer.masksToBounds = true
            }
        }
        
        guard animated else {
            applyTransform()
            return
        }
        
        collectionView.layoutIfNeeded()
        
        UIView.animate(
            withDuration: configuration.scaleDownDuration,
            delay: 0,
            options: [.curveEaseOut, .layoutSubviews],
            animations: {
                applyTransform()
                self.collectionView.layoutIfNeeded()
            }
        )
    }
    
    private func restoreScaleToVisibleCells(animated: Bool) {
        let applyTransform = {
            for cell in self.collectionView.visibleCells {
                cell.transform = .identity
                cell.layer.cornerRadius = 0
            }
        }
        
        guard animated else {
            applyTransform()
            return
        }
        
        collectionView.layoutIfNeeded()
        
        UIView.animate(
            withDuration: configuration.restoreDuration,
            delay: 0,
            usingSpringWithDamping: configuration.springDamping,
            initialSpringVelocity: 0,
            options: [.layoutSubviews],
            animations: {
                applyTransform()
                self.collectionView.layoutIfNeeded()
            }
        )
    }
    
    private func updateProgressiveScaling() {
        guard configuration.scalingBehavior == .progressive else { return }
        
        let pageWidth = collectionView.bounds.width
        guard pageWidth > 0 else { return }
        
        let contentOffset = collectionView.contentOffset.x
        
        for cell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell) else { continue }
            
            let cellOffset = CGFloat(indexPath.item) * pageWidth
            let normalizedOffset = (cellOffset - contentOffset) / pageWidth
            let distance = abs(normalizedOffset)
            
            let scale = interpolate(from: 1.0, to: configuration.transitionScale, progress: min(distance, 1.0))
            let cornerRadius = concentricCornerRadius(for: scale)
            
            cell.transform = CGAffineTransform(scaleX: scale, y: scale)
            cell.layer.cornerRadius = cornerRadius
            cell.layer.masksToBounds = true
        }
    }
    
    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
    
    private func concentricCornerRadius(for scale: CGFloat) -> CGFloat {
        let screenWidth = view.bounds.width
        let scaledWidth = screenWidth * scale
        let inset = (screenWidth - scaledWidth) / 2
        let concentricRadius = max(0, configuration.cornerRadius - inset)
        return concentricRadius / scale
    }
    
    private func scaleForCell(at indexPath: IndexPath) -> CGFloat {
        switch configuration.scalingBehavior {
        case .none:
            return 1.0
        case .uniform:
            return isScrolling ? configuration.transitionScale : 1.0
        case .progressive:
            let pageWidth = collectionView.bounds.width
            guard pageWidth > 0 else { return 1.0 }
            
            let contentOffset = collectionView.contentOffset.x
            let cellOffset = CGFloat(indexPath.item) * pageWidth
            let normalizedOffset = (cellOffset - contentOffset) / pageWidth
            let distance = abs(normalizedOffset)
            
            return interpolate(from: 1.0, to: configuration.transitionScale, progress: min(distance, 1.0))
        }
    }
}

// MARK: - Prefetching

extension PageSwipeViewController {
    
    private func notifyNeighborPages() {
        prefetchPageAtIndex(currentPageIndex - 1)
        prefetchPageAtIndex(currentPageIndex + 1)
    }
    
    private func prefetchPageAtIndex(_ index: Int) {
        guard index >= 0, index < pages.count else { return }
        pages[index].prefetchable?.prefetchData()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension PageSwipeViewController: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        collectionView.bounds.size
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let scale = scaleForCell(at: indexPath)
        
        guard scale != 1.0 else {
            cell.transform = .identity
            cell.layer.cornerRadius = 0
            return
        }
        
        cell.transform = CGAffineTransform(scaleX: scale, y: scale)
        cell.layer.cornerRadius = concentricCornerRadius(for: scale)
        cell.layer.masksToBounds = true
    }
}

// MARK: - UIScrollViewDelegate

extension PageSwipeViewController: UIScrollViewDelegate {
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard !isScrolling else { return }
        
        isScrolling = true
        scrollingDidBeginSubject.send()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        
        if !isAdjustingContentOffset {
            updateCurrentPageIndexIfNeeded(for: scrollView)
        }
        
        contentOffsetSubject.send(scrollView.contentOffset)
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        
        let currentOffset = scrollView.contentOffset.x
        let currentPage = currentOffset / pageWidth
        
        let targetPage = calculateTargetPage(currentPage: currentPage, velocity: velocity.x)
        
        targetContentOffset.pointee = CGPoint(x: CGFloat(targetPage) * pageWidth, y: 0)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        scrollingDidEnd()
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollingDidEnd()
    }
}

// MARK: - Scroll View Helpers

extension PageSwipeViewController {
    
    private func updateCurrentPageIndexIfNeeded(for scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        let newIndex = Int(round(scrollView.contentOffset.x / pageWidth))
        
        guard newIndex != currentPageIndex, newIndex >= 0, newIndex < pages.count else { return }
        
        currentPageIndex = newIndex
    }
    
    private func calculateTargetPage(currentPage: CGFloat, velocity: CGFloat) -> Int {
        var targetPage: Int
        
        if abs(velocity) > configuration.velocityThreshold / 1000 {
            if velocity > 0 {
                targetPage = Int(ceil(currentPage))
            } else {
                targetPage = Int(floor(currentPage))
            }
        } else {
            targetPage = Int(round(currentPage))
        }
        
        return max(0, min(targetPage, pages.count - 1))
    }
    
    private func scrollingDidEnd() {
        guard isScrolling else { return }
        
        isScrolling = false
        scrollingDidEndSubject.send()
    }
}
