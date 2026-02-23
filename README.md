# PageSwipeKit

A UIKit-based paging controller that mimics the iOS app switcher behavior with smooth animations, configurable scaling, and dynamic page management.

## Features

- **UIKit-native paging** using `UICollectionView` with diffable data source
- **Concentric corner radius** alignment during scale transitions
- **Multiple scaling behaviors**: uniform, progressive, or none
- **Dynamic page management** - append, prepend, and remove pages at runtime
- **Pre-fetching callbacks** for neighbor pages via `Prefetchable` protocol
- **Programmatic navigation** with `setCurrentPage(_:animated:)`
- **Combine publishers** for scroll state and page change events
- **SwiftUI integration** - wrap SwiftUI views with `UIHostingController`
- **iOS 15+** compatible

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nicothin/PageSwipeKit.git", from: "1.0.0")
]
```

Or add it directly in Xcode via File → Add Package Dependencies.

## Usage

### Basic Usage

```swift
import UIKit
import PageSwipeKit

let page1 = SwipePage(viewController: MyViewController1())
let page2 = SwipePage(viewController: MyViewController2())
let page3 = SwipePage(viewController: MyViewController3())

let pageSwipeController = PageSwipeViewController(
    pages: [page1, page2, page3]
)
```

### With SwiftUI Views

```swift
import SwiftUI
import PageSwipeKit

let swiftUIView = MySwiftUIView()
let page = SwipePage(
    view: swiftUIView,
    prefetchable: myViewModel  // ViewModel conforming to Prefetchable
)

let pageSwipeController = PageSwipeViewController(pages: [page])
```

### With Configuration

```swift
let configuration = PageSwipeConfiguration(
    scalingBehavior: .uniform,
    transitionScale: 0.92,
    cornerRadius: 44,
    velocityThreshold: 300,
    scaleDownDuration: 0.15,
    restoreDuration: 0.35,
    springDamping: 0.8
)

let pageSwipeController = PageSwipeViewController(
    pages: pages,
    configuration: configuration
)
```

### Using Presets

```swift
// Default configuration (uniform scaling)
let controller = PageSwipeViewController(pages: pages, configuration: .default)

// No scaling - pages slide without shrinking
let controller = PageSwipeViewController(pages: pages, configuration: .noScale)

// Progressive scaling - pages scale based on distance from center
let controller = PageSwipeViewController(pages: pages, configuration: .progressive)
```

## Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `scalingBehavior` | `ScalingBehavior` | `.uniform` | How pages scale during transitions |
| `transitionScale` | `CGFloat` | `0.92` | Scale factor during transition (0.0-1.0) |
| `cornerRadius` | `CGFloat` | `44` | Corner radius of pages (matches device corners) |
| `velocityThreshold` | `CGFloat` | `300` | Swipe velocity to trigger page change |
| `scaleDownDuration` | `TimeInterval` | `0.15` | Duration of scale-down animation |
| `restoreDuration` | `TimeInterval` | `0.35` | Duration of spring restore animation |
| `springDamping` | `CGFloat` | `0.8` | Spring damping ratio (0.0-1.0) |

## Scaling Behaviors

### `.none`
Pages remain full size during transitions. Simple slide effect.

### `.uniform`
All visible pages scale together when dragging begins, and scale back to full size when the gesture ends.

### `.progressive`
Pages scale based on their distance from the center. The centered page is full size, while adjacent pages are scaled down.

## Page Management

### Navigation

```swift
// Navigate to a specific page
pageSwipeController.setCurrentPage(page, animated: true)

// Go to next/previous page
pageSwipeController.goToNextPage(animated: true)
pageSwipeController.goToPreviousPage(animated: true)

// Check navigation availability
if pageSwipeController.hasNextPage { ... }
if pageSwipeController.hasPreviousPage { ... }
```

### Dynamic Updates

```swift
// Replace all pages
pageSwipeController.setPages(newPages, initialPage: specificPage)

// Append a page to the end
pageSwipeController.append(newPage)

// Prepend a page (automatically adjusts current index)
pageSwipeController.prepend(newPage)

// Remove a page
pageSwipeController.remove(page)
```

### Properties

```swift
pageSwipeController.currentPage      // Current SwipePage (nil if empty)
pageSwipeController.pages            // Array of all pages
pageSwipeController.isScrolling      // Whether currently scrolling
pageSwipeController.configuration    // Current configuration (@Published)
```

## Combine Publishers

```swift
import Combine

var cancellables = Set<AnyCancellable>()

// Subscribe to page changes (emits current page immediately)
pageSwipeController.currentPageDidChangePublisher
    .sink { page in
        print("Current page: \(page.id)")
    }
    .store(in: &cancellables)

// Subscribe to scroll state
pageSwipeController.scrollingDidBeginPublisher
    .sink {
        hideUI()
    }
    .store(in: &cancellables)

pageSwipeController.scrollingDidEndPublisher
    .sink {
        showUI()
    }
    .store(in: &cancellables)
```

## Prefetching

Implement the `Prefetchable` protocol to load data before a page becomes visible:

```swift
final class MyViewModel: Prefetchable {
    func prefetchData() {
        // Load data for this page
        Task {
            await loadContent()
        }
    }
}

// Attach to a page
let page = SwipePage(
    viewController: myViewController,
    prefetchable: myViewModel
)
```

Prefetching is automatically triggered when a page becomes a neighbor of the current page.

## SwipePage

`SwipePage` bundles a view controller with optional prefetching:

```swift
// UIKit view controller
let page = SwipePage(viewController: myVC)

// With prefetchable
let page = SwipePage(
    viewController: myVC,
    prefetchable: myPrefetchable
)

// SwiftUI view with prefetchable
let page = SwipePage(
    view: MySwiftUIView(),
    prefetchable: myViewModel
)

// Custom page ID
let page = SwipePage(
    pageId: UUID(),
    viewController: myVC
)
```

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 13.0+

## License

MIT License
