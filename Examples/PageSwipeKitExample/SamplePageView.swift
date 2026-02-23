//
//  SamplePageView.swift
//  ScrollViewTest
//
//  Sample page view for demonstrating the container.
//

import SwiftUI
import Combine
import PageSwipeKit

// MARK: - Random Name Generator

private let pageNames = [
    "Apollo", "Blaze", "Cosmic", "Drift", "Echo", "Frost", "Galaxy", "Horizon",
    "Iris", "Jade", "Karma", "Luna", "Mystic", "Nova", "Orbit", "Pixel",
    "Quasar", "Ripple", "Solar", "Thunder", "Unity", "Vortex", "Whisper", "Xenon",
    "Yonder", "Zenith", "Aurora", "Breeze", "Crystal", "Dawn", "Ember", "Flame"
]

// MARK: - View Model

class SamplePageViewModel: ObservableObject, Prefetchable {
    let pageName: String
    @Published var isDataLoaded = false
    
    init(pageName: String) {
        self.pageName = pageName
    }
    
    /// Creates a view model with a random name
    static func withRandomName() -> SamplePageViewModel {
        let name = pageNames.randomElement() ?? "Unknown"
        return SamplePageViewModel(pageName: name)
    }
    
    func prefetchData() {
        // This is where you would load data for this page
        // For example: fetch from network, load from database, prepare images, etc.
        print("🔄 Pre-fetching data for page: \(pageName)")
        isDataLoaded = true
    }
}

// MARK: - View

struct SamplePageView: View {
    
    @ObservedObject var viewModel: SamplePageViewModel
    
    private let pageColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .cyan, .indigo
    ]
    
    private var backgroundColor: Color {
        // Use hash of name for consistent color
        let hash = abs(viewModel.pageName.hashValue)
        let index = hash % pageColors.count
        return pageColors[index]
    }
    
    private var fillerText: String {
        let paragraph = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
        
        """
        // Use hash of name for deterministic random length (1-12 paragraphs)
        let hash = abs(viewModel.pageName.hashValue)
        let repeatCount = (hash % 12) + 1
        return String(repeating: paragraph, count: repeatCount)
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 100)
                    
                    Text(viewModel.pageName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Swipe left or right")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    // Demo scrollable content to show nested scroll handling
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<10) { item in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay {
                                        Text("\(item + 1)")
                                            .foregroundStyle(.white)
                                            .font(.title2)
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 120)
                    
                    Text("↑ Scroll horizontally here")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    // Filler text
                    Text(fillerText)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }
                .padding(.bottom, 100)
            }
        }
    }
}

#Preview {
    SamplePageView(viewModel: SamplePageViewModel(pageName: "Preview"))
}
