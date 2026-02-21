//
//  SettingsView.swift
//  PageSwipeKitExample
//
//  Created by stoyan on 20.02.26.
//

import SwiftUI
import PageSwipeKit

struct SettingsView: View {
    
    // MARK: - Properties
    
    @Binding var configuration: PageSwipeConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var stiffness: Double = 300
    @State private var damping: Double = 30
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                scalingSection
                appearanceSection
                gestureSection
                animationSection
                presetsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Scaling Section

extension SettingsView {
    
    private var scalingSection: some View {
        Section {
            Picker("Scaling Behavior", selection: $configuration.scalingBehavior) {
                Text("None").tag(ScalingBehavior.none)
                Text("Uniform").tag(ScalingBehavior.uniform)
                Text("Progressive").tag(ScalingBehavior.progressive)
            }
            
            if configuration.scalingBehavior != .none {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Transition Scale")
                        Spacer()
                        Text(String(format: "%.2f", configuration.transitionScale))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $configuration.transitionScale, in: 0.7...1.0, step: 0.01)
                }
            }
        } header: {
            Text("Scaling")
        } footer: {
            Text(scalingFooterText)
        }
    }
    
    private var scalingFooterText: String {
        switch configuration.scalingBehavior {
        case .none:
            return "Pages remain full size during transitions."
        case .uniform:
            return "All pages scale together when dragging begins."
        case .progressive:
            return "Pages scale based on distance from center."
        }
    }
}

// MARK: - Appearance Section

extension SettingsView {
    
    private var appearanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Corner Radius")
                    Spacer()
                    Text("\(Int(configuration.cornerRadius)) pt")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $configuration.cornerRadius, in: 0...100, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Page Gap")
                    Spacer()
                    Text("\(Int(configuration.pageGap)) pt")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $configuration.pageGap, in: 0...50, step: 1)
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Corner radius creates concentric alignment with device corners when scaled.")
        }
    }
}

// MARK: - Gesture Section

extension SettingsView {
    
    private var gestureSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Velocity Threshold")
                    Spacer()
                    Text("\(Int(configuration.velocityThreshold)) pt/s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $configuration.velocityThreshold, in: 100...1000, step: 50)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Rubber Band Resistance")
                    Spacer()
                    Text(String(format: "%.2f", configuration.rubberBandResistance))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $configuration.rubberBandResistance, in: 0...1, step: 0.05)
            }
        } header: {
            Text("Gesture")
        } footer: {
            Text("Velocity threshold determines how fast you need to swipe to change pages. Rubber band controls edge bounce resistance.")
        }
    }
}

// MARK: - Animation Section

extension SettingsView {
    
    private var animationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Spring Stiffness")
                    Spacer()
                    Text("\(Int(stiffness))")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $stiffness, in: 50...500, step: 10)
                    .onChange(of: stiffness) { newValue in
                        configuration.snapAnimation = .interpolatingSpring(stiffness: newValue, damping: damping)
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Spring Damping")
                    Spacer()
                    Text("\(Int(damping))")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $damping, in: 5...60, step: 1)
                    .onChange(of: damping) { newValue in
                        configuration.snapAnimation = .interpolatingSpring(stiffness: stiffness, damping: newValue)
                    }
            }
        } header: {
            Text("Animation")
        } footer: {
            Text("Controls the snap animation when releasing a page. Higher stiffness = faster, higher damping = less bounce.")
        }
    }
}

// MARK: - Presets Section

extension SettingsView {
    
    private var presetsSection: some View {
        Section {
            Button("Default") {
                configuration = .default
            }
            
            Button("No Scale") {
                configuration = .noScale
            }
            
            Button("Progressive") {
                configuration = .progressive
            }
            
            Button("Bouncy") {
                configuration = PageSwipeConfiguration(
                    cornerRadius: 64,
                    pageGap: 8,
                    scalingBehavior: .uniform,
                    transitionScale: 0.88,
                    velocityThreshold: 200,
                    snapAnimation: .interpolatingSpring(stiffness: 200, damping: 15),
                    rubberBandResistance: 0.3
                )
            }
            
            Button("Snappy") {
                configuration = PageSwipeConfiguration(
                    cornerRadius: 64,
                    pageGap: 8,
                    scalingBehavior: .uniform,
                    transitionScale: 0.95,
                    velocityThreshold: 400,
                    snapAnimation: .interpolatingSpring(stiffness: 500, damping: 40),
                    rubberBandResistance: 0.7
                )
            }
        } header: {
            Text("Presets")
        }
    }
}

#Preview {
    SettingsView(configuration: .constant(.default))
}
