//
//  SettingsView.swift
//  ScrollViewTest
//
//  Settings view for configuring PageSwipeConfiguration.
//

import SwiftUI
import PageSwipeKit

struct SettingsView: View {
    
    // MARK: - Properties
    
    @Binding var configuration: PageSwipeConfiguration
    @Environment(\.dismiss) private var dismiss
    
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
            return "All pages scale uniformly when dragging begins."
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
        } header: {
            Text("Gesture")
        } footer: {
            Text("Velocity threshold determines how fast you need to swipe to change pages.")
        }
    }
}

// MARK: - Animation Section

extension SettingsView {
    
    private var animationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Scale Down Duration")
                    Spacer()
                    Text(String(format: "%.2fs", configuration.scaleDownDuration))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $configuration.scaleDownDuration, in: 0.05...0.5, step: 0.05)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Restore Duration")
                    Spacer()
                    Text(String(format: "%.2fs", configuration.restoreDuration))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $configuration.restoreDuration, in: 0.1...0.8, step: 0.05)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Spring Damping")
                    Spacer()
                    Text(String(format: "%.2f", configuration.springDamping))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $configuration.springDamping, in: 0.3...1.0, step: 0.05)
            }
        } header: {
            Text("Animation")
        } footer: {
            Text("Controls the animation timing. Lower spring damping = more bounce.")
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
                    scalingBehavior: .uniform,
                    transitionScale: 0.88,
                    cornerRadius: 64,
                    velocityThreshold: 200,
                    scaleDownDuration: 0.15,
                    restoreDuration: 0.5,
                    springDamping: 0.5
                )
            }
            
            Button("Snappy") {
                configuration = PageSwipeConfiguration(
                    scalingBehavior: .uniform,
                    transitionScale: 0.95,
                    cornerRadius: 44,
                    velocityThreshold: 400,
                    scaleDownDuration: 0.1,
                    restoreDuration: 0.25,
                    springDamping: 0.9
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
