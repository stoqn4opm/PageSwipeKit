# PageSwipeKit

A SwiftUI component that mimics the iOS app switcher page swiping behavior with smooth animations, configurable scaling, and dynamic page management.

## Features

- **Interactive drag gesture** with velocity-based snapping
- **Concentric corner radius** alignment during scale transitions
- **Multiple scaling behaviors**: uniform, progressive, or none
- **Rubber-band bounce** at first/last page edges
- **Dynamic page management** - append and prepend pages at runtime
- **Pre-fetching callbacks** for neighbor pages
- **Programmatic navigation** with configurable animations
- **Scroll callbacks** for hiding/showing UI during transitions
- **Inner scroll view priority** - nested horizontal ScrollViews work correctly
- **iOS 15+** compatible

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/PageSwipeKit.git", from: "1.0.0")
]
```

Or add it directly in Xcode via File → Add Package Dependencies.

## Usage

### Basic Usage

```swift
import SwiftUI
import PageSwipeKit

struct ContentView: View {
    @StateObject private var dataSource = PageSwipeDataSource<Int>(
        initialPages: [1, 2, 3],
        initialIndex: 0
    )
    
    var body: some View {
        PageSwipeView(dataSource: dataSource) { pageID in
            Text("Page \(pageID)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue)
        }
    }
}
```

### With Configuration

```swift
PageSwipeView(
    dataSource: dataSource,
    configuration: PageSwipeConfiguration(
        cornerRadius: 64,
        pageGap: 8,
        scalingBehavior: .uniform,
        transitionScale: 0.92,
        velocityThreshold: 300,
        rubberBandResistance: 0.55
    )
) { pageID in
    // Your page content
}
```

### Using Presets

```swift
// Default configuration (uniform scaling)
PageSwipeView(dataSource: dataSource, configuration: .default) { ... }

// No scaling - pages slide without shrinking
PageSwipeView(dataSource: dataSource, configuration: .noScale) { ... }

// Progressive scaling - pages scale based on distance from center
PageSwipeView(dataSource: dataSource, configuration: .progressive) { ... }
```

## Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `cornerRadius` | `CGFloat` | `64` | Corner radius of pages (matches device corners) |
| `pageGap` | `CGFloat` | `8` | Gap between pages during transition |
| `scalingBehavior` | `ScalingBehavior` | `.uniform` | How pages scale during transitions |
| `transitionScale` | `CGFloat` | `0.92` | Scale factor during transition (0.0-1.0) |
| `velocityThreshold` | `CGFloat` | `300` | Swipe velocity to trigger page change |
| `snapAnimation` | `Animation` | Spring | Animation for snapping to pages |
| `rubberBandResistance` | `CGFloat` | `0.55` | Edge bounce resistance (0.0-1.0) |

## Scaling Behaviors

### `.none`
Pages remain full size during transitions. Simple slide effect.

### `.uniform`
All visible pages scale together when dragging begins, and scale back to full size when the gesture ends.

### `.progressive`
Pages scale based on their distance from the center. The centered page is full size, while adjacent pages are scaled down.

## Data Source

`PageSwipeDataSource` manages the collection of pages and provides methods for dynamic updates:

```swift
let dataSource = PageSwipeDataSource<String>(
    initialPages: ["page1", "page2", "page3"],
    initialIndex: 0
)

// Append pages
dataSource.append("page4")
dataSource.append(["page5", "page6"])

// Prepend pages (automatically adjusts current index)
dataSource.prepend("page0")

// Remove pages
dataSource.remove(at: 0)

// Navigate programmatically
dataSource.navigateToIndex(2)
dataSource.navigateToPage("page3")

// Replace all pages
dataSource.replaceAll(with: ["new1", "new2"])
```

### Callbacks

```swift
// Called when a page becomes a neighbor (for pre-fetching)
dataSource.onPageBecameNeighbor = { pageID in
    loadData(for: pageID)
}

// Called when scrolling begins
dataSource.onScrollBegan = {
    withAnimation { hideUI = true }
}

// Called when scrolling ends
dataSource.onScrollEnded = {
    withAnimation { hideUI = false }
}
```

### Properties

```swift
dataSource.currentPageIndex  // Current page index
dataSource.currentPageID     // Current page identifier
dataSource.pageCount         // Total number of pages
dataSource.pageIDs           // Array of all page identifiers
dataSource.isScrolling       // Whether currently scrolling
```

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 13.0+

## License

MIT License
