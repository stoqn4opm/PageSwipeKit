//
//  ContentView.swift
//  PageSwipeKitExample
//
//  Created by stoyan on 20.02.26.
//

import SwiftUI
import PageSwipeKit

struct ContentView: View {
    
    // MARK: - Properties
    
    @StateObject private var dataSource = PageSwipeDataSource<Int>(
        initialPages: [1, 2, 3],
        initialIndex: 0
    )
    
    @State private var isNavigationBarVisible: Bool = true
    @State private var configuration: PageSwipeConfiguration = .default
    @State private var isSettingsPresented: Bool = false
    
    private let pageColors: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .pink,
        .red,
        .cyan,
        .indigo
    ]
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            PageSwipeView(
                dataSource: dataSource,
                configuration: configuration
            ) { pageID in
                pageContent(for: pageID)
            }
            .id(configuration.scalingBehavior)
            
            navigationBar
            bottomControls
        }
        .onAppear {
            setupDataSourceCallbacks()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(configuration: $configuration)
        }
    }
    
    private func setupDataSourceCallbacks() {
        dataSource.onPageBecameNeighbor = { pageID in
            print("Pre-fetching data for page \(pageID)")
        }
        
        dataSource.onScrollBegan = {
            withAnimation(.easeOut(duration: 0.2)) {
                isNavigationBarVisible = false
            }
        }
        
        dataSource.onScrollEnded = {
            withAnimation(.easeIn(duration: 0.25)) {
                isNavigationBarVisible = true
            }
        }
    }
}

// MARK: - Navigation Bar

extension ContentView {
    
    private var navigationBar: some View {
        VStack {
            HStack {
                Button {
                    // Back action
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Page \(dataSource.currentPageID ?? 0)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("\(dataSource.currentPageIndex + 1) of \(dataSource.pageCount)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.6), .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Spacer()
        }
        .opacity(isNavigationBarVisible ? 1 : 0)
        .offset(y: isNavigationBarVisible ? 0 : -20)
    }
}

// MARK: - Page Content

extension ContentView {
    
    private func pageContent(for pageID: Int) -> some View {
        // Safe modulo that handles negative numbers
        let colorIndex = ((pageID % pageColors.count) + pageColors.count) % pageColors.count
        
        return ZStack {
            pageColors[colorIndex]
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Page \(pageID)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Swipe left or right")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                
                // Demo scrollable content to show gesture conflict handling
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
            }
        }
    }
}

// MARK: - Bottom Controls

extension ContentView {
    
    private var bottomControls: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Page management buttons
                HStack(spacing: 16) {
                    Button {
                        let newID = (dataSource.pageIDs.min() ?? 1) - 1
                        dataSource.prepend(newID)
                    } label: {
                        Label("Prepend", systemImage: "plus.circle.fill")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    Text("\(dataSource.pageCount) pages")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    
                    Button {
                        let newID = (dataSource.pageIDs.max() ?? 0) + 1
                        dataSource.append(newID)
                    } label: {
                        Label("Append", systemImage: "plus.circle.fill")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                
                // Navigation buttons
                HStack(spacing: 20) {
                    Button {
                        if dataSource.currentPageIndex > 0 {
                            dataSource.navigateToIndex(dataSource.currentPageIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .disabled(dataSource.currentPageIndex == 0)
                    .opacity(dataSource.currentPageIndex == 0 ? 0.3 : 1)
                    
                    // Page indicator
                    Text("\(dataSource.currentPageIndex + 1) / \(dataSource.pageCount)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    
                    Button {
                        if dataSource.currentPageIndex < dataSource.pageCount - 1 {
                            dataSource.navigateToIndex(dataSource.currentPageIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .disabled(dataSource.currentPageIndex == dataSource.pageCount - 1)
                    .opacity(dataSource.currentPageIndex == dataSource.pageCount - 1 ? 0.3 : 1)
                }
            }
            .padding(.bottom, 50)
            .opacity(isNavigationBarVisible ? 1 : 0)
            .offset(y: isNavigationBarVisible ? 0 : 20)
        }
    }
    
}

#Preview {
    ContentView()
}
