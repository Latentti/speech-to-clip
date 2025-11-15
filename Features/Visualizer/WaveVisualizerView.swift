//
//  WaveVisualizerView.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 3.7: Replace Matrix Code Rain with Wave Visualizer
//

import SwiftUI

/// SwiftUI view that renders the wave visualization using Canvas
///
/// WaveVisualizerView provides the SwiftUI interface for the wave renderer.
/// Uses Canvas for high-performance drawing and TimelineView for 60fps updates.
///
/// Key Features:
/// - 50px width × full screen height canvas
/// - 60fps animation via TimelineView(.animation)
/// - Calls WaveRenderer.drawWave() each frame
/// - Positioned on right screen edge
///
/// Usage:
/// ```swift
/// WaveVisualizerView(renderer: waveRenderer)
/// ```
struct WaveVisualizerView: View {
    // MARK: - Properties

    /// Wave renderer that manages state and drawing logic
    @ObservedObject var renderer: WaveRenderer

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Draw the wave (update called separately via onChange)
                renderer.drawWave(context: &context, size: size)
            }
            .frame(width: 50) // 50px width as per web prototype
            .frame(maxHeight: .infinity) // Full screen height
            .onChange(of: timeline.date) { _ in
                // Update renderer state outside Canvas drawing context
                // This prevents "Publishing changes from within view updates" warning
                renderer.update()
            }
        }
    }
}

// MARK: - Preview

#Preview("Wave Visualizer - Idle") {
    // Create AppState with initial state
    let appState = AppState()
    let renderer = WaveRenderer(appState: appState)

    WaveVisualizerView(renderer: renderer)
        .frame(width: 50, height: 400)
        .background(Color.black)
}
