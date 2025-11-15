//
//  VisualizerContentView.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 3.1: Create Floating Visualizer Window
//  Updated Story 3.3: Implement Canvas-Based Code Rain Animation
//  Updated Story 3.7: Replace Matrix Code Rain with Wave Visualizer
//

import SwiftUI

/// SwiftUI view for the visualizer window content
///
/// Displays the wave audio visualization using WaveVisualizerView with Canvas rendering.
/// The view renders a smooth sine wave at 60fps that reacts to audio amplitude.
///
/// Story 3.7: Replaced MatrixView with WaveVisualizerView for cleaner, modern visualization.
@MainActor
struct VisualizerContentView: View {
    // MARK: - Properties

    /// Reference to central app state
    let appState: AppState

    /// Wave renderer for visualization
    /// Note: Using @ObservedObject instead of @StateObject to allow external ownership.
    /// This ensures WaveRenderer is initialized eagerly when the view is created,
    /// preventing missed state updates during first activation.
    @ObservedObject var waveRenderer: WaveRenderer

    // MARK: - Initialization

    init(appState: AppState, waveRenderer: WaveRenderer) {
        self.appState = appState
        self.waveRenderer = waveRenderer
    }

    // MARK: - Body

    var body: some View {
        WaveVisualizerView(renderer: waveRenderer)
    }
}

#Preview {
    // Create AppState with initial state
    let appState = AppState()
    let renderer = WaveRenderer(appState: appState)
    // Note: Cannot modify appState here in macOS 13.5
    // Preview shows idle state

    VisualizerContentView(appState: appState, waveRenderer: renderer)
        .frame(width: 50, height: 400)
        .background(Color.black)
}
